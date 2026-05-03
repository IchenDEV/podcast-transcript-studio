from io import BytesIO

from fastapi.testclient import TestClient


def test_web_routes_create_list_and_show_job(tmp_path, monkeypatch):
    from podcast_web.app import create_app
    from podcast_web.services import transcription as transcription_service

    def fake_start_job(repository, settings, job_id, source_path, filename, diarize, clean_fillers, mode='standard'):
        repository.update_job(job_id, status='completed', output_path=str(tmp_path / 'transcript.txt'))
        (tmp_path / 'transcript.txt').write_text(
            '【分节1】（约 180 秒）\n\n[00:00:00.000 - 00:00:01.000] 张三: 大家好，我是张三，测试内容\n',
            encoding='utf-8',
        )

    monkeypatch.setattr(transcription_service, 'start_job', fake_start_job)

    app = create_app(testing=True)
    client = TestClient(app)

    response = client.get('/')
    assert response.status_code == 200
    assert '新建任务' in response.text
    assert '转写模式' in response.text
    assert '标准' in response.text

    upload = BytesIO(b'fake audio bytes')
    create = client.post(
        '/jobs',
        files={'file': ('demo.m4a', upload, 'audio/mp4')},
        data={'diarize': 'on', 'clean_fillers': 'on', 'mode': 'quick'},
        follow_redirects=False,
    )
    assert create.status_code in (302, 303)

    listing = client.get('/jobs')
    assert listing.status_code == 200
    assert 'demo.m4a' in listing.text

    detail = client.get('/jobs/1')
    assert detail.status_code == 200
    assert '测试内容' in detail.text
    assert '可读稿' in detail.text
    assert '张三：大家好，我是张三，测试内容' in detail.text
    assert '<span class="speaker">张三</span>' in detail.text

    download = client.get('/jobs/1/download/txt')
    assert download.status_code == 200
    assert '测试内容' in download.text


def test_web_routes_can_create_job_from_podcast_url(tmp_path, monkeypatch):
    import podcast_web.app as app_module
    from podcast_web.app import create_app
    from podcast_web.services import transcription as transcription_service

    source_path = tmp_path / 'uploads' / 'remote.mp3'

    def fake_download(source_url, destination_dir):
        source_path.parent.mkdir(parents=True, exist_ok=True)
        source_path.write_bytes(b'remote audio bytes')
        return source_path, None

    def fake_start_job(repository, settings, job_id, source_path, filename, diarize, clean_fillers, mode='standard'):
        repository.update_job(job_id, status='running')

    monkeypatch.setattr(app_module, 'download_podcast_audio', fake_download)
    monkeypatch.setattr(transcription_service, 'start_job', fake_start_job)

    app = create_app(testing=True)
    client = TestClient(app)

    create = client.post(
        '/jobs',
        data={
            'source_url': 'https://www.xiaoyuzhoufm.com/episode/demo',
            'diarize': 'on',
            'clean_fillers': 'on',
            'mode': 'standard',
        },
        follow_redirects=False,
    )

    assert create.status_code in (302, 303)
    listing = client.get('/jobs')
    assert listing.status_code == 200
    assert 'remote.mp3' in listing.text
