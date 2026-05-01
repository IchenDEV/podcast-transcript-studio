from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile

from packages.transcriber.modes import UserMode, resolve_mode_settings
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from packages.podcast_fetcher import PodcastAudioError, download_podcast_audio
from podcast_web.config import get_settings
from podcast_web.db import Base, make_engine, make_session_factory
from podcast_web.repository import JobRepository
from podcast_web.services.parser import parse_transcript_text
from podcast_web.services import transcription as transcription_service



def create_app(testing: bool = False) -> FastAPI:
    settings = get_settings(testing=testing)
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    settings.uploads_dir.mkdir(parents=True, exist_ok=True)
    settings.jobs_dir.mkdir(parents=True, exist_ok=True)

    engine = make_engine(str(settings.db_path))
    Base.metadata.create_all(engine)
    session_factory = make_session_factory(engine)
    repository = JobRepository(session_factory)
    templates = Jinja2Templates(directory=str(settings.base_dir / 'podcast_web' / 'templates'))

    app = FastAPI(title="Podcast Transcript Studio")
    app.state.settings = settings
    app.state.engine = engine
    app.state.SessionLocal = session_factory
    app.state.repository = repository
    app.mount('/static', StaticFiles(directory=str(settings.base_dir / 'podcast_web' / 'static')), name='static')

    @app.get("/", response_class=HTMLResponse)
    def index(request: Request):
        modes = [resolve_mode_settings(mode) for mode in UserMode]
        return templates.TemplateResponse(request, 'index.html', {'title': '新建任务', 'modes': modes, 'default_mode': UserMode.STANDARD.value})

    @app.get("/jobs", response_class=HTMLResponse)
    def jobs(request: Request):
        return templates.TemplateResponse(request, 'jobs.html', {'jobs': repository.list_jobs(), 'title': '任务列表'})

    @app.post('/jobs')
    def create_job(
        file: Optional[UploadFile] = File(default=None),
        source_url: Optional[str] = Form(default=None),
        diarize: Optional[str] = Form(default=None),
        clean_fillers: Optional[str] = Form(default=None),
        mode: str = Form(default=UserMode.STANDARD.value),
    ):
        link = (source_url or '').strip()
        if link:
            try:
                source_path, _ = download_podcast_audio(link, settings.uploads_dir)
            except PodcastAudioError as error:
                raise HTTPException(status_code=400, detail=str(error)) from error
            filename = source_path.name
        elif file and file.filename:
            source_path = transcription_service.save_upload(settings, file, file.filename)
            filename = file.filename
        else:
            raise HTTPException(status_code=400, detail='请选择音频文件，或输入播客链接。')

        job = repository.create_job(filename=filename, source_path=str(source_path))
        transcription_service.start_job(
            repository=repository,
            settings=settings,
            job_id=job.id,
            source_path=source_path,
            filename=filename,
            diarize=bool(diarize),
            clean_fillers=bool(clean_fillers),
            mode=mode,
        )
        return RedirectResponse(url=f'/jobs/{job.id}', status_code=303)

    @app.get('/jobs/{job_id}', response_class=HTMLResponse)
    def job_detail(request: Request, job_id: int):
        job = repository.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail='Job not found')
        document = None
        json_path = None
        if job.output_path and Path(job.output_path).exists():
            document = parse_transcript_text(Path(job.output_path).read_text(encoding='utf-8'))
            candidate_json = Path(job.output_path).with_suffix('.json')
            if candidate_json.exists():
                json_path = str(candidate_json)
        return templates.TemplateResponse(
            request,
            'job_detail.html',
            {'job': job, 'document': document, 'json_path': json_path, 'title': f'任务 {job.id}'},
        )

    @app.get('/jobs/{job_id}/download/{kind}')
    def download(job_id: int, kind: str):
        job = repository.get_job(job_id)
        if not job or not job.output_path:
            raise HTTPException(status_code=404, detail='Output not found')
        path = Path(job.output_path)
        if kind == 'json':
            path = path.with_suffix('.json')
        if not path.exists():
            raise HTTPException(status_code=404, detail='File not found')
        return FileResponse(path)

    @app.post('/demo/seed')
    def seed_demo():
        demo_source = settings.uploads_dir / 'demo.m4a'
        demo_source.write_bytes(b'demo audio placeholder')
        job = repository.create_job(filename='demo.m4a', source_path=str(demo_source), status='completed')
        job_dir = settings.jobs_dir / str(job.id)
        job_dir.mkdir(parents=True, exist_ok=True)
        transcript_path = job_dir / 'transcript.txt'
        transcript_path.write_text(
            '【分节1】（约 180 秒）\n\n[00:00:00.000 - 00:00:03.000] 说话人1: Demo transcript line\n',
            encoding='utf-8',
        )
        json_path = job_dir / 'transcript.json'
        json_path.write_text(
            '[{"start": 0.0, "end": 3.0, "speaker": "说话人1", "text": "Demo transcript line"}]',
            encoding='utf-8',
        )
        repository.update_job(job.id, output_path=str(transcript_path), status='completed')
        return {'job_id': job.id}

    return app


app = create_app()
