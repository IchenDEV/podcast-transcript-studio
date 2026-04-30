import importlib


def test_worker_cli_module_exists():
    module = importlib.import_module('packages.python_worker.cli')
    assert hasattr(module, 'main')


def test_worker_cli_resolves_existing_script():
    module = importlib.import_module('packages.python_worker.cli')
    script = module.worker_script_path()

    assert script.name == 'transcribe_with_speaker_segmentation.py'
    assert script.exists()
