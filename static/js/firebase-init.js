// Firebase config is set as window.FIREBASE_CONFIG by Hugo at build time (see head.html partial).
firebase.initializeApp(window.FIREBASE_CONFIG);

// Global sign-out
async function authSignOut() {
  await firebase.auth().signOut();
  window.location.href = "/";
}

// Navbar auth state
firebase.auth().onAuthStateChanged(user => {
  const emailEl   = document.getElementById("nav-user-email");
  const logoutBtn = document.getElementById("btn-logout");
  const loginBtn  = document.getElementById("btn-login");
  const navLinks  = document.getElementById("nav-links");

  if (user) {
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
