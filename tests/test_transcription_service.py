from pathlib import Path

from podcast_web.config import Settings


def make_settings(tmp_path):
    return Settings(
        base_dir=Path.cwd(),
        data_dir=tmp_path,
        uploads_dir=tmp_path / 'uploads',
        jobs_dir=tmp_path / 'jobs',
        db_path=tmp_path / 'jobs.sqlite3',
        testing=True,
    )


def test_build_transcription_command_uses_packaged_worker(tmp_path):
    from podcast_web.services.transcription import build_transcription_command

    cmd, output_txt, output_json = build_transcription_command(
        settings=make_settings(tmp_path),
        job_id=12,
        source_path=tmp_path / 'demo.m4a',
        filename='demo.m4a',
        diarize=True,
        clean_fillers=True,
    )

    assert cmd[0] == 'python3'
    assert cmd[1].endswith('packages/python_worker/cli.py')
    assert '--diarize' in cmd
    assert '--json' in cmd
    assert '--preset' in cmd
    assert 'balanced' in cmd
    assert '--text-model' in cmd
    assert 'Qwen/Qwen3-0.6B' in cmd
    assert output_txt.name == 'transcript.txt'
    assert output_json.name == 'transcript.json'


def test_build_transcription_command_can_switch_to_quick_mode(tmp_path):
    from podcast_web.services.transcription import build_transcription_command

    cmd, _, _ = build_transcription_command(
        settings=make_settings(tmp_path),
        job_id=13,
        source_path=tmp_path / 'demo.m4a',
        filename='demo.m4a',
        diarize=False,
        clean_fillers=False,
        mode='quick',
    )

    assert '--preset' in cmd
    assert 'lite' in cmd
    assert '--keep-fillers' in cmd
    assert '--diarize' not in cmd
