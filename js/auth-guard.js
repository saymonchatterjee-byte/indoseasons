// ---------------------------------------------------------------------------
// Auth guard — include this on every protected page, AFTER config.js.
//
// Usage on a page:
//   <script src="js/config.js"></script>
//   <script src="js/auth-guard.js"></script>
//   <script>
//     requireAuth({ allowedRoles: ['admin'] }).then(({ session, profile }) => {
//       // session and profile are ready here; render the page.
//     });
//   </script>
// ---------------------------------------------------------------------------

/**
 * Checks session + role, redirects to login.html if not authenticated,
 * and shows a restricted-access message if the role doesn't match.
 * Resolves with { session, profile } once access is confirmed.
 */
async function requireAuth({ allowedRoles } = {}) {
  const { data: { session } } = await supabaseClient.auth.getSession();

  if (!session) {
    window.location.href = 'login.html';
    return new Promise(() => {}); // never resolves; we're navigating away
  }

  const { data: profile } = await supabaseClient
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();

  if (profile && profile.is_active === false) {
    renderAccessMessage({
      title: 'Account disabled',
      body: 'Your access has been deactivated. Contact an administrator to restore it.',
    });
    return new Promise(() => {});
  }

  if (allowedRoles && allowedRoles.length > 0) {
    const hasAccess = profile ? allowedRoles.includes(profile.role) : false;
    if (!hasAccess) {
      renderAccessMessage({
        title: 'Restricted area',
        body: `Your role (${profile ? profile.role : 'unknown'}) doesn't have permission to view this page.`,
      });
      return new Promise(() => {});
    }
  }

  return { session, profile };
}

function renderAccessMessage({ title, body }) {
  document.body.innerHTML = `
    <div class="center-screen">
      <div class="box">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#F0A202" stroke-width="2" style="margin:0 auto;">
          <path d="M12 9v4M12 17h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
        </svg>
        <p>${title}</p>
        <p>${body}</p>
      </div>
    </div>
  `;
}

async function logout() {
  await supabaseClient.auth.signOut();
  window.location.href = 'login.html';
}
