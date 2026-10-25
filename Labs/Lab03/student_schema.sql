-- Lab 03: write ALL FIVE complete CREATE TABLE statements here.
-- Read SCHEMA_CONTRACT.md for column names, types and integrity requirements.
-- Supply assets, subset_requests, download_attempts, artifacts, artifact_locations.
-- Include your chosen primary/foreign keys, uniqueness rules and CHECK constraints.
-- Do not change or recreate the existing five Lab 02 tables.
-- Run python check_lab03.py, then init your archive after checks pass.

CREATE TABLE assets (
    asset_id TEXT NOT NULL PRIMARY KEY,
    collection TEXT NOT NULL,
    item_id TEXT NOT NULL,
    asset_key TEXT CHECK (asset_key IN ('red', 'nir')) NOT NULL,
    source_url TEXT NOT NULL,
    metadata_json TEXT NOT NULL,
    metadata_sha256 TEXT NOT NULL,
    created_at TEXT NOT NULL,
    CONSTRAINT u_assets UNIQUE(collection, item_id, asset_key, metadata_sha256),
    FOREIGN KEY (collection, item_id) REFERENCES scenes(collection, item_id)
);

CREATE TABLE subset_requests (
    subset_id TEXT NOT NULL PRIMARY KEY,
    asset_id TEXT NOT NULL REFERENCES assets(asset_id),
    aoi_key TEXT NOT NULL,
    aoi_json TEXT NOT NULL,
    recipe_version TEXT NOT NULL,
    status TEXT CHECK (status IN ('pending', 'ready', 'failed')) NOT NULL,
    latest_artifact_id TEXT,
    updated_at TEXT NOT NULL,
    CONSTRAINT u_subset_requests UNIQUE(asset_id, aoi_key, recipe_version),
    CONSTRAINT chk_ready_has_artifact CHECK (
        (status != 'ready') OR (latest_artifact_id IS NOT NULL)
    ),
    FOREIGN KEY (latest_artifact_id, subset_id) REFERENCES artifacts(artifact_id, subset_id)
);

CREATE TABLE download_attempts(
    attempt_id TEXT NOT NULL PRIMARY KEY,
    subset_id TEXT NOT NULL REFERENCES subset_requests(subset_id),
    run_id TEXT NOT NULL REFERENCES runs(run_id),
    status TEXT CHECK (status IN ('running', 'succeeded', 'reused', 'failed')) NOT NULL,
    stage TEXT NOT NULL,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    network_bytes INTEGER NOT NULL DEFAULT 0,
    http_status INTEGER,
    artifact_id TEXT,
    error_code TEXT,
    error_message TEXT,
    UNIQUE(attempt_id, subset_id),
    CONSTRAINT chk_download_attempts_byte_count CHECK (network_bytes >= 0),
    CONSTRAINT chk_running_finish_time CHECK (
        (status = 'running' AND finished_at IS NULL)
        OR (status != 'running' AND finished_at IS NOT NULL)
    ),
    CONSTRAINT chk_success_has_artifact CHECK (
        (status NOT IN ('succeeded', 'reused')) OR (artifact_id IS NOT NULL)
    ),
    FOREIGN KEY (artifact_id, subset_id) REFERENCES artifacts(artifact_id, subset_id)
);

CREATE TABLE artifacts (
    artifact_id TEXT NOT NULL PRIMARY KEY,
    subset_id TEXT NOT NULL REFERENCES subset_requests(subset_id),
    created_by_attempt_id TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    raster_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    CONSTRAINT u_artifacts UNIQUE(subset_id, sha256),
    UNIQUE(artifact_id, subset_id),
    CONSTRAINT chk_artifacts_size_bytes CHECK (size_bytes > 0),
    FOREIGN KEY (created_by_attempt_id, subset_id) REFERENCES download_attempts(attempt_id, subset_id)
);

CREATE TABLE artifact_locations (
    location_id TEXT NOT NULL PRIMARY KEY,
    artifact_id TEXT NOT NULL REFERENCES artifacts(artifact_id),
    local_path TEXT NOT NULL UNIQUE,
    status TEXT CHECK (status IN ('available', 'missing', 'corrupt')) NOT NULL,
    checked_at TEXT NOT NULL
);

CREATE INDEX idx_download_attempts_run_id ON download_attempts(run_id);
CREATE INDEX idx_download_attempts_subset_id ON download_attempts(subset_id);
