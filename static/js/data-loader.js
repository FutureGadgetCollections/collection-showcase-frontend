// Requires window.DATA_CONFIG = { gcsBucket, githubDataRepo }

async function loadFromGitHub(filename) {
  const { githubDataRepo } = window.DATA_CONFIG || {};
  if (!githubDataRepo) throw new Error('DATA_CONFIG.githubDataRepo is not set');
  const url = `https://raw.githubusercontent.com/${githubDataRepo}/main/${filename}?t=${Date.now()}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GitHub returned ${res.status} for ${filename}`);
  return res.json();
}

async function loadFromGCS(filename) {
  const { gcsBucket } = window.DATA_CONFIG || {};
  if (!gcsBucket) throw new Error('DATA_CONFIG.gcsBucket is not set');
  const url = `https://storage.googleapis.com/${gcsBucket}/${filename}?t=${Date.now()}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GCS returned ${res.status} for ${filename}`);
  return res.json();
}

// GitHub-first with GCS fallback — used for initial page loads.
async function loadJsonData(filename) {
  const { githubDataRepo } = window.DATA_CONFIG || {};
  if (githubDataRepo) {
    try { return await loadFromGitHub(filename); } catch (e) {
      console.warn(`[data-loader] GitHub failed for ${filename}, falling back to GCS:`, e);
    }
  }
  return loadFromGCS(filename);
}
