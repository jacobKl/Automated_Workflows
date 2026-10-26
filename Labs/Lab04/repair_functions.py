"""Three plausible implementations to investigate and repair. No syntax puzzles."""
import hashlib
import json
import numpy as np

def _normalize(value):
    if isinstance(value, dict):
        return {key: _normalize(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_normalize(item) for item in value]
    if isinstance(value, bool) or value is None:
        return value
    if isinstance(value, (int, float)):
        return float(value)
    return value

def make_request_spec(science, inputs, environment, runtime):
    """Return (normalized_spec, fingerprint). Read the contract before editing."""
    # It remembers enough to run once. Does it identify the calculation reliably?
    spec = {
        'stage': science['stage'],
        'settings': _normalize(science),
        'inputs': [
            {
                'role': role,
                'artifact_id': inputs[role]['artifact_id'],
                'sha256': inputs[role]['sha256'],
                'size_bytes': inputs[role]['size_bytes'],
                'raster': _normalize(inputs[role]['raster']),
                'lineage': _normalize(inputs[role]['lineage']),
            }
            for role in ('red', 'nir')
        ],
        'equivalence_policy': environment['policy'],
        'code_sha256': environment['code_sha256'],
    }

    fingerprint = hashlib.sha256(json.dumps(spec, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()

    return spec, fingerprint

def validate_pair(red, nir):
    """Raise ValueError if metadata cannot justify a red/NIR calculation."""
    # Both arrays have the same size, so this seems safe at first glance.

    if red['raster']['shape'] != nir['raster']['shape']:
        raise ValueError('Input shapes differ')

    if (red['raster']['transform'] != nir['raster']['transform']):
        raise ValueError('Input transforms differ')

    if (red['raster']['crs'] != nir['raster']['crs']):
        raise ValueError('Input CRSs differ')

    if (red['lineage']['item_id'] != nir['lineage']['item_id']):
        raise ValueError('Input item IDs differ')

    if (red['lineage']['aoi_key'] != nir['lineage']['aoi_key']):
        raise ValueError('Input item IDs differ')

    if red['lineage'].get('asset_key') != 'red' or nir['lineage'].get('asset_key') != 'nir':
        raise ValueError('Input roles/asset keys are incompatible')

    for role, meta in (('red', red), ('nir', nir)):
        scale = meta['raster'].get('scale')
        if scale is None or not np.isfinite(scale) or scale <= 0:
            raise ValueError(f'{role} scale must be a positive finite value')


def calculate_ndvi(red, nir, red_meta, nir_meta, epsilon):
    """Return float32 NDVI; invalid pixels must be NaN. Inputs are stored DN."""
    # Shared scaling cancels in a ratio. Is that the whole calibration here?
    r = red.astype('float64') * red_meta['scale'] + red_meta['offset']
    n = nir.astype('float64') * nir_meta['scale'] + nir_meta['offset']
    valid = (red != red_meta['nodata']) & (nir != nir_meta['nodata']) & (np.abs(n + r) > epsilon)
    with np.errstate(divide='ignore', invalid='ignore'):
        return np.where(valid, (n - r) / (n + r), np.nan).astype('float32')
