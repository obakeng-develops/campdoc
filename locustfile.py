import json
import os
import threading
from collections import deque
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

from locust import HttpUser, between, task
from locust.exception import StopUser


HOST = os.getenv("CAMPSEND_LOAD_HOST", "http://localhost:3000")
if urlparse(HOST).hostname not in {"localhost", "127.0.0.1", "::1"}:
    raise RuntimeError("Campsend load tests only run against localhost.")

FIXTURES = Path(os.getenv("CAMPSEND_LOAD_FIXTURES", "tmp/locust_users.json"))
if not FIXTURES.exists():
    raise RuntimeError("Run `bin/rails runner script/prepare_load_test.rb` first.")

DATA = json.loads(FIXTURES.read_text())
SENDERS = deque(DATA["users"])
SENDERS_LOCK = threading.Lock()
MAX_DELIVERIES = int(os.getenv("CAMPSEND_LOAD_MAX_DELIVERIES", "3"))


class CsrfParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.token = None

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "meta" and values.get("name") == "csrf-token":
            self.token = values.get("content")


def csrf_token(response):
    parser = CsrfParser()
    parser.feed(response.text)
    if not parser.token:
        raise StopUser("Response did not include a CSRF token.")
    return parser.token


class SenderUser(HttpUser):
    host = HOST
    wait_time = between(0.5, 2)
    weight = 10

    def on_start(self):
        with SENDERS_LOCK:
            if not SENDERS:
                raise StopUser("Spawned more users than prepared fixtures.")
            self.fixture = SENDERS.popleft()

        page = self.client.get(self.fixture["login_path"], name="GET /sign-in/:id")
        with self.client.post(
            self.fixture["login_path"],
            data={"authenticity_token": csrf_token(page), "token": self.fixture["login_token"]},
            allow_redirects=False,
            name="POST /sign-in/:id",
            catch_response=True,
        ) as response:
            if response.status_code != 302:
                response.failure(f"Expected sign-in redirect, got {response.status_code}")
                raise StopUser()
        self.deliveries_created = 0
        self.delivery_paths = []

    @task(5)
    def browse_files(self):
        self.client.get("/files", name="GET /files")

    @task(4)
    def open_composer(self):
        self.client.get("/sends/new", name="GET /sends/new")

    @task(3)
    def browse_sent(self):
        self.client.get("/sends", name="GET /sends")

    @task(2)
    def view_collection(self):
        self.client.get(self.fixture["collection_path"], name="GET /collections/:id")

    @task(2)
    def create_delivery(self):
        if self.deliveries_created >= MAX_DELIVERIES:
            return

        page = self.client.get("/sends/new", name="GET /sends/new [write]")
        data = [
            ("authenticity_token", csrf_token(page)),
            ("send[recipient_email]", "locust-recipient@example.test"),
            ("send[message]", "Local load test"),
            ("send[files][]", self.fixture["blob_signed_id"]),
        ]
        with self.client.post(
            "/sends",
            data=data,
            allow_redirects=False,
            name="POST /sends",
            catch_response=True,
        ) as response:
            if response.status_code == 302:
                self.deliveries_created += 1
                self.delivery_paths.append(response.headers["Location"])
            else:
                response.failure(f"Expected delivery redirect, got {response.status_code}")

    @task(2)
    def view_delivery(self):
        if self.delivery_paths:
            self.client.get(self.delivery_paths[-1], name="GET /sends/:id")


class RecipientUser(HttpUser):
    host = HOST
    wait_time = between(2, 4)
    fixed_count = 1

    def on_start(self):
        self.fixture = DATA["recipient"]
        page = self.client.get(self.fixture["delivery_path"], name="GET /d/:id [access]")
        with self.client.post(
            f'{self.fixture["delivery_path"]}/access',
            data={"authenticity_token": csrf_token(page), "token": self.fixture["access_token"]},
            allow_redirects=False,
            name="POST /d/:id/access",
            catch_response=True,
        ) as response:
            if response.status_code != 302:
                response.failure(f"Expected access redirect, got {response.status_code}")
                raise StopUser()

    @task(4)
    def view_delivery(self):
        self.client.get(self.fixture["delivery_path"], name="GET /d/:id")

    @task(1)
    def download_file(self):
        page = self.client.get(self.fixture["delivery_path"], name="GET /d/:id [download]")
        self.client.post(
            f'{self.fixture["delivery_path"]}/files/{self.fixture["attachment_id"]}/download',
            data={"authenticity_token": csrf_token(page)},
            name="POST /d/:id/files/:id/download",
        )
