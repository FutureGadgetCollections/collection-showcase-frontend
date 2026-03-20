// Firebase config is set as window.FIREBASE_CONFIG by Hugo at build time (see head.html partial).
firebase.initializeApp(window.FIREBASE_CONFIG);

// Global sign-out
async function authSignOut() {
  await firebase.auth().signOut();
  window.location.href = "/";
}

// Sign in with Google popup
async function signInWithGoogle() {
  const provider = new firebase.auth.GoogleAuthProvider();
  try {
    await firebase.auth().signInWithPopup(provider);
    // onAuthStateChanged handles whitelist check and redirect
  } catch (e) {
    if (e.code !== 'auth/popup-closed-by-user') {
      showToast('Sign-in failed: ' + e.message, 'danger');
    }
  }
}

// Returns true if the email is in the allowed list (or if no list is configured).
function isEmailAllowed(email) {
  const allowed = (window.ALLOWED_EMAILS || [])
    .map(e => e.trim().toLowerCase())
    .filter(Boolean);
  if (allowed.length === 0) return true; // no restriction configured
  return allowed.includes(email.toLowerCase());
}

// Navbar auth state + whitelist enforcement
firebase.auth().onAuthStateChanged(async user => {
  const emailEl   = document.getElementById("nav-user-email");
  const logoutBtn = document.getElementById("btn-logout");
  const loginBtn  = document.getElementById("btn-login");
  const navLinks  = document.getElementById("nav-links");

  if (user) {
    if (!isEmailAllowed(user.email)) {
      await firebase.auth().signOut();
      // Will re-enter this handler with user=null; show error on home page if present
      const errEl = document.getElementById('auth-error');
      if (errEl) {
        errEl.textContent = user.email + ' is not authorized to access this app.';
        errEl.classList.remove('d-none');
      } else {
        showToast(user.email + ' is not authorized.', 'danger');
      }
      return;
    }

    if (emailEl)   emailEl.textContent = user.email;
    if (logoutBtn) logoutBtn.classList.remove("d-none");
    if (loginBtn)  loginBtn.classList.add("d-none");
    if (navLinks)  navLinks.style.removeProperty("display");
  } else {
    if (emailEl)   emailEl.textContent = "";
    if (logoutBtn) logoutBtn.classList.add("d-none");
    if (loginBtn)  loginBtn.classList.remove("d-none");
    if (navLinks)  navLinks.style.setProperty("display", "none", "important");
  }
});
