import subprocess

from packages.podcast_fetcher.resolver import ResolvedPodcastAudio


def test_cli_runs_worker_for_local_audio(tmp_path, monkeypatch):
    from podcast_transcript_studio import cli

    audio = tmp_path / 'demo.wav'
    audio.write_bytes(b'RIFF')
    output = tmp_path / 'nested' / 'result.txt'
    json_output = tmp_path / 'nested' / 'result.json'
    calls = []

    def fake_run(cmd, check):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0)

    monkeypatch.setattr(cli.subprocess, 'run', fake_run)

    exit_code = cli.run([
        str(audio),
        '--output',
        str(output),
        '--json',
        str(json_output),
        '--mode',
        'quick',
        '--skip-text-refinement',
    ])

    assert exit_code == 0
    assert len(calls) == 1
    cmd = calls[0]
    assert cmd[1].endswith('packages/python_worker/cli.py')
    assert cmd[cmd.index('--audio') + 1] == str(audio.resolve())
    assert cmd[cmd.index('--output') + 1] == str(output.resolve())
    assert cmd[cmd.index('--json') + 1] == str(json_output.resolve())
    assert cmd[cmd.index('--preset') + 1] == 'lite'
    assert cmd[cmd.index('--asr-provider') + 1] == 'whisper'
    assert '--diarize' not in cmd
    assert '--skip-text-refinement' in cmd


def test_cli_downloads_public_podcast_url_and_uses_title_for_default_outputs(tmp_path, monkeypatch):
    from podcast_transcript_studio import cli

    downloaded_audio = tmp_path / 'work' / 'audio' / 'episode.m4a'
    downloaded_audio.parent.mkdir(parents=True)
    downloaded_audio.write_bytes(b'audio')
    calls = []

    def fake_download(source_url, destination_dir):
        assert source_url == 'https://podcasts.example/show/episode'
        assert destination_dir == (tmp_path / 'work' / 'audio').resolve()
        return downloaded_audio, ResolvedPodcastAudio(
            page_url=source_url,
            audio_url='https://media.example.com/episode.m4a',
            title='Demo Episode',
            platform='generic',
        )

    def fake_run(cmd, check):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0)

    monkeypatch.setattr(cli, 'download_podcast_audio', fake_download)
    monkeypatch.setattr(cli.subprocess, 'run', fake_run)

    exit_code = cli.run([
        'https://podcasts.example/show/episode',
        '--output-dir',
        str(tmp_path / 'out'),
        '--work-dir',
        str(tmp_path / 'work'),
        '--json',
    ])

    assert exit_code == 0
    cmd = calls[0]
    assert cmd[cmd.index('--audio') + 1] == str(downloaded_audio.resolve())
    assert cmd[cmd.index('--output') + 1] == str((tmp_path / 'out' / 'Demo Episode.txt').resolve())
    assert cmd[cmd.index('--json') + 1] == str((tmp_path / 'out' / 'Demo Episode.json').resolve())
    assert cmd[cmd.index('--preset') + 1] == 'balanced'


def test_cli_high_quality_diarization_defaults_can_be_disabled(tmp_path, monkeypatch):
    from podcast_transcript_studio import cli

    audio = tmp_path / 'demo.m4a'
    audio.write_bytes(b'audio')
    calls = []

    def fake_run(cmd, check):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0)

    monkeypatch.setattr(cli.subprocess, 'run', fake_run)

    cli.run([
        str(audio),
        '--output',
        str(tmp_path / 'high.txt'),
        '--mode',
        'high_quality',
    ])
    cli.run([
        str(audio),
        '--output',
        str(tmp_path / 'plain.txt'),
        '--mode',
        'high_quality',
        '--no-diarize',
    ])

    high_quality_cmd = calls[0]
    no_diarize_cmd = calls[1]
    assert high_quality_cmd[high_quality_cmd.index('--preset') + 1] == 'production'
    assert high_quality_cmd[high_quality_cmd.index('--asr-provider') + 1] == 'auto'
    assert '--diarize' in high_quality_cmd
    assert '--diarize' not in no_diarize_cmd
