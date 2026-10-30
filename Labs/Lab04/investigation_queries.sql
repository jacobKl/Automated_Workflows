-- Write and retain your diagnostic queries here. Use the notebook questions.
-- Enable enforcement when opening your own SQLite session:
PRAGMA foreign_keys = ON;

-- Q1. List requests with their number of attempts, grouped by outcome.
SELECT request_id, status, count(*) as COUNT FROM processing_attempts GROUP BY request_id,status;

-- Q2. Starting from an NDVI artifact ID, find its successful producing attempt,
-- normalized request, each input role, original Lab 3 subset, scene, band and AOI.
    SELECT
        ndvi.artifact_id AS ndvi_artifact_id,
        ndvi.sha256 AS ndvi_sha256,
        o.role AS output_role,
        a.attempt_id,
        a.status AS attempt_status,
        a.stage AS attempt_stage,
        r.request_id,
        r.fingerprint,
        r.stage AS request_stage,
        r.normalized_json,
        i.role AS input_role,
        pin.artifact_id AS input_artifact_id,
        pin.source_artifact_id AS lab3_artifact_id,
        s.subset_id,
        s.aoi_key,
        s.aoi_json,
        assets.collection,
        assets.item_id,
        assets.asset_key,
        assets.source_url,
        sc.acquired_at,
        sc.cloud_cover
    FROM processing_artifacts AS ndvi
    JOIN processing_outputs AS o
    ON o.artifact_id = ndvi.artifact_id
    JOIN processing_attempts AS a
    ON a.attempt_id = o.attempt_id
    AND a.status = 'succeeded'
    JOIN processing_requests AS r
    ON r.request_id = a.request_id
    JOIN processing_inputs AS i
    ON i.request_id = r.request_id
    JOIN processing_artifacts AS pin
    ON pin.artifact_id = i.artifact_id
    LEFT JOIN artifacts AS lab3
    ON lab3.artifact_id = pin.source_artifact_id
    LEFT JOIN subset_requests AS s
    ON s.subset_id = lab3.subset_id
    LEFT JOIN assets
    ON assets.asset_id = s.asset_id
    LEFT JOIN scenes AS sc
    ON sc.collection = assets.collection
    AND sc.item_id = assets.item_id
    WHERE ndvi.source_artifact_id IS NULL
    ORDER BY i.role;

-- Q3. Find failed/interrupted attempts with stage and error; retain recovery rows.
    SELECT a.attempt_id, a.status, a.stage, a.error_code, a.error_message,
        i.role, i.artifact_id, l.local_path, l.status AS location_status
    FROM processing_attempts AS a
    JOIN processing_inputs AS i ON i.request_id = a.request_id
    JOIN processing_artifact_locations AS l ON l.artifact_id = i.artifact_id
    WHERE a.status IN ('failed', 'interrupted')
    ORDER BY a.started_at, i.role;

-- Q4. Find succeeded attempts whose returned artifact has no available location.
-- Explain why SQL alone cannot prove current filesystem availability.
SELECT
    a.attempt_id,
    a.request_id,
    a.status,
    o.role,
    o.artifact_id,
    l.local_path,
    l.status AS location_status,
    l.checked_at
FROM processing_attempts AS a
JOIN processing_outputs AS o
    ON o.attempt_id = a.attempt_id
LEFT JOIN processing_artifact_locations AS l
    ON l.artifact_id = o.artifact_id
WHERE a.status = 'succeeded'
  AND (l.location_id IS NULL OR l.status <> 'available');

-- Because SQL cannot check if the file is actually present on the disk.

-- Q5. Find running attempts and inspect temp/final path, receipt and output links.
SELECT
    a.attempt_id,
    a.request_id,
    a.status,
    a.stage,
    a.started_at,
    a.finished_at,
    a.error_code,
    a.temp_path,
    a.final_path,
    a.receipt_json IS NOT NULL AS has_receipt,
    json_extract(a.receipt_json, '$.sha256') AS receipt_sha256,
    o.role AS output_role,
    o.artifact_id AS output_artifact_id
FROM processing_attempts AS a
LEFT JOIN processing_outputs AS o
    ON o.attempt_id = a.attempt_id
WHERE a.status = 'running'
ORDER BY a.started_at;

-- Q6. Compare original calibration metadata with the reviewed configuration.
SELECT
    i.role,
    i.artifact_id,
    json_extract(pin.raster_json, '$.scale') AS file_scale,
    json_extract(pin.raster_json, '$.offset') AS file_offset,
    json_extract(r.normalized_json, '$.settings.calibration.' || i.role || '.scale') AS reviewed_scale,
    json_extract(r.normalized_json, '$.settings.calibration.' || i.role || '.offset') AS reviewed_offset,
    json_extract(r.normalized_json, '$.settings.calibration.' || i.role || '.evidence') AS review_evidence
FROM processing_requests AS r
JOIN processing_inputs AS i
    ON i.request_id = r.request_id
JOIN processing_artifacts AS pin
    ON pin.artifact_id = i.artifact_id
ORDER BY r.request_id, i.role;