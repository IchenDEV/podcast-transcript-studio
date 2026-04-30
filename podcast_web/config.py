from pathlib import Path
from dataclasses import dataclass
import tempfile


@dataclass
class Settings:
    base_dir: Path
    data_dir: Path
    uploads_dir: Path
    jobs_dir: Path
    db_path: Path
    testing: bool = False


def get_settings(testing: bool = False) -> Settings:
    base_dir = Path(__file__).resolve().parent.parent
    data_root = Path(tempfile.mkdtemp(prefix='podcast-web-')) if testing else base_dir / 'data'
    uploads = data_root / "uploads"
    jobs = data_root / "jobs"
    db_path = data_root / "podcast_web.sqlite3"
    return Settings(
        base_dir=base_dir,
        data_dir=data_root,
        uploads_dir=uploads,
        jobs_dir=jobs,
        db_path=db_path,
        testing=testing,
    )
