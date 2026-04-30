from packages.transcriber.modes import UserMode, resolve_mode_settings


def test_standard_mode_maps_to_balanced_defaults():
    settings = resolve_mode_settings(UserMode.STANDARD)

    assert settings.worker_preset == 'balanced'
    assert settings.label == '标准'


def test_high_quality_mode_enables_diarization_by_default():
    settings = resolve_mode_settings(UserMode.HIGH_QUALITY)

    assert settings.worker_preset == 'production'
    assert settings.default_diarize is True
