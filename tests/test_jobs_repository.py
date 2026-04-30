from podcast_web.config import get_settings
from podcast_web.db import Base, make_engine, make_session_factory
from podcast_web.models import Job


def build_repo(tmp_path):
    from podcast_web.repository import JobRepository

    db_path = tmp_path / "jobs.sqlite3"
    engine = make_engine(str(db_path))
    Base.metadata.create_all(engine)
    session_factory = make_session_factory(engine)
    return JobRepository(session_factory)


def test_job_repository_create_update_and_list(tmp_path):
    repo = build_repo(tmp_path)

    first = repo.create_job(filename="a.m4a", source_path="/tmp/a.m4a")
    second = repo.create_job(filename="b.m4a", source_path="/tmp/b.m4a")

    repo.update_job(first.id, status="completed", output_path="/tmp/out.txt")

    jobs = repo.list_jobs()

    assert [job.filename for job in jobs] == ["b.m4a", "a.m4a"]
    refreshed = repo.get_job(first.id)
    assert refreshed.status == "completed"
    assert refreshed.output_path == "/tmp/out.txt"
    assert refreshed.source_path == "/tmp/a.m4a"
