#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

from check_rootless_container_setup import (
    REPO_ROOT,
    load_json,
    validate_cloud_control_plane,
    validate_devcontainer,
    validate_dockerfile,
    validate_cloud_workflow,
    validate_repository,
    validate_settings,
    validate_supabase_ports,
)


class RootlessContainerSetupTest(unittest.TestCase):
    def test_repository_contract_validates(self) -> None:
        self.assertEqual(validate_repository(REPO_ROOT), [])

    def test_rejects_root_or_privileged_devcontainer(self) -> None:
        config = load_json(REPO_ROOT / ".devcontainer" / "flutter-local" / "devcontainer.json")
        broken = copy.deepcopy(config)
        broken["containerUser"] = "root"
        broken["runArgs"].append("--privileged")

        errors = validate_devcontainer(broken)

        self.assertTrue(any("non-root" in error for error in errors), errors)
        self.assertTrue(any("privileged" in error for error in errors), errors)

    def test_rejects_privileged_forwarded_port(self) -> None:
        config = load_json(REPO_ROOT / ".devcontainer" / "flutter-local" / "devcontainer.json")
        broken = copy.deepcopy(config)
        broken["forwardPorts"] = [80]

        errors = validate_devcontainer(broken)

        self.assertTrue(any(">= 1024" in error for error in errors), errors)

    def test_rejects_host_runtime_socket_mount(self) -> None:
        config = load_json(REPO_ROOT / ".devcontainer" / "flutter-local" / "devcontainer.json")
        broken = copy.deepcopy(config)
        broken["mounts"] = [
            "source=/run/user/1000/podman/podman.sock,target=/var/run/docker.sock,type=bind"
        ]

        errors = validate_devcontainer(broken)

        self.assertTrue(any("socket" in error or ".sock" in error for error in errors), errors)

    def test_accepts_lightweight_cloud_control_plane(self) -> None:
        config = load_json(REPO_ROOT / ".devcontainer" / "devcontainer.json")

        self.assertEqual(validate_cloud_control_plane(config), [])

    def test_rejects_flutter_in_cloud_control_plane_startup(self) -> None:
        config = load_json(REPO_ROOT / ".devcontainer" / "devcontainer.json")
        broken = copy.deepcopy(config)
        broken["postCreateCommand"] = "flutter pub get"

        errors = validate_cloud_control_plane(broken)

        self.assertTrue(any("lightweight" in error for error in errors), errors)
        self.assertTrue(any("flutter" in error for error in errors), errors)
    def test_rejects_wrong_container_clients(self) -> None:
        errors = validate_settings(
            {
                "containers.containerClient": "docker",
                "containers.orchestratorClient": "docker-compose",
                "dev.containers.dockerPath": "docker",
            }
        )

        self.assertEqual(len(errors), 3)

    def test_rejects_root_final_dockerfile_user(self) -> None:
        errors = validate_dockerfile("FROM ubuntu@sha256:abc\nUSER root\n")

        self.assertTrue(any("USER vscode" in error for error in errors), errors)
        self.assertTrue(any("USER root" in error for error in errors), errors)

    def test_rejects_privileged_supabase_port(self) -> None:
        errors = validate_supabase_ports(
            {
                "api": {"port": 80},
                "db": {"port": 54322, "shadow_port": 54320},
                "studio": {"port": 54323, "api_url": "http://127.0.0.1"},
                "inbucket": {"port": 54324},
            }
        )

        self.assertTrue(any("api.port" in error for error in errors), errors)

    def test_rejects_unsafe_or_incomplete_cloud_workflow(self) -> None:
        errors = validate_cloud_workflow(
            "pull_request_target:\nsecrets.API_KEY\n--privileged\n",
            "podman info\n",
            "sudo dockerd\nsupabase start\n--ignore-health-check\n",
        )

        self.assertTrue(any("pull_request_target" in error for error in errors), errors)
        self.assertTrue(any("secrets." in error for error in errors), errors)
        self.assertTrue(any("--privileged" in error for error in errors), errors)
        self.assertTrue(any("stop --no-backup" in error for error in errors), errors)
        self.assertTrue(any("sudo dockerd" in error for error in errors), errors)
        self.assertTrue(any("--ignore-health-check" in error for error in errors), errors)


if __name__ == "__main__":
    unittest.main()