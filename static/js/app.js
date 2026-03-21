// Triggers POST /sync and shows a toast with the result.
async function triggerSync(btn) {
  const orig = btn.innerHTML;
  btn.disabled = true;
  btn.innerHTML = '<i class="bi bi-arrow-clockwise me-1 spin"></i>Syncing…';
  try {
    await api('POST', '/sync');
    showToast('Sync started — data files will update shortly.', 'success');
  } catch (e) {
    showToast('Sync failed: ' + e.message, 'danger');
  } finally {
    btn.disabled = false;
    btn.innerHTML = orig;
  }
}

// Global toast helper
function showToast(message, type = "secondary") {
  let container = document.getElementById("toast-container");
  if (!container) {
    container = document.createElement("div");
    container.id = "toast-container";
    container.className = "toast-container position-fixed bottom-0 end-0 p-3";
    document.body.appendChild(container);
  }
  const id = "toast-" + Date.now();
  container.insertAdjacentHTML("beforeend", `
    <div id="${id}" class="toast align-items-center text-bg-${type} border-0" role="alert">
      <div class="d-flex">
        <div class="toast-body">${message}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    </div>
  `);
  const el = document.getElementById(id);
  new bootstrap.Toast(el, { delay: 4000 }).show();
  el.addEventListener("hidden.bs.toast", () => el.remove());
}
