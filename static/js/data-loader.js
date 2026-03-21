// Fetches a JSON file: tries GitHub raw first, falls back to GCS.
// Requires window.DATA_CONFIG = { gcsBucket, githubDataRepo }
async function loadJsonData(filename) {
  const { gcsBucket, githubDataRepo } = window.DATA_CONFIG || {};

  // --- Try GitHub raw ---
  if (githubDataRepo) {
    try {
      const res = await fetch(`https://raw.githubusercontent.com/${githubDataRepo}/main/${filename}`);
      if (res.ok) return await res.json();
      console.warn(`GitHub fetch returned ${res.status} for ${filename}, falling back to GCS`);
    } catch (e) {
      console.warn(`GitHub fetch failed for ${filename}, falling back to GCS:`, e);
    }
  }

  // --- Fall back to GCS ---
  if (!gcsBucket) throw new Error('DATA_CONFIG.gcsBucket is not set');
  const gcsRes = await fetch(`https://storage.googleapis.com/${gcsBucket}/${filename}`);
  if (!gcsRes.ok) throw new Error(`GCS fetch failed for ${filename}: ${gcsRes.status}`);
  return await gcsRes.json();
}
