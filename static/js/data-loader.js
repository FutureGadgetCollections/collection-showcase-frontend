// Fetches a JSON file from Google Drive first, falls back to GCS.
// Requires window.DATA_CONFIG = { gcsBucket, driveFolderId, driveApiKey }
async function loadJsonData(filename) {
  const { gcsBucket, driveFolderId, driveApiKey } = window.DATA_CONFIG || {};

  // --- Try Google Drive ---
  // Note: the Drive folder and files must be shared as "Anyone with the link can view"
  // for this to work without user authentication.
  if (driveFolderId && driveApiKey) {
    try {
      const q = encodeURIComponent(`name='${filename}' and '${driveFolderId}' in parents and trashed=false`);
      const searchRes = await fetch(
        `https://www.googleapis.com/drive/v3/files?q=${q}&fields=files(id)&key=${driveApiKey}`
      );
      if (searchRes.ok) {
        const { files } = await searchRes.json();
        if (files && files.length > 0) {
          const fileRes = await fetch(
            `https://www.googleapis.com/drive/v3/files/${files[0].id}?alt=media&key=${driveApiKey}`
          );
          if (fileRes.ok) return await fileRes.json();
        }
      }
    } catch (e) {
      console.warn(`Drive fetch failed for ${filename}, falling back to GCS:`, e);
    }
  }

  // --- Fall back to GCS ---
  if (!gcsBucket) throw new Error('DATA_CONFIG.gcsBucket is not set');
  const gcsRes = await fetch(`https://storage.googleapis.com/${gcsBucket}/${filename}`);
  if (!gcsRes.ok) throw new Error(`GCS fetch failed for ${filename}: ${gcsRes.status}`);
  return await gcsRes.json();
}
