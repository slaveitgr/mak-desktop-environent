The makOS authentication agent is a derivative of the original Cutefish
`polkit-agent` subtree at the exact commit used by the pinned ISO. See
`source.json` for source identities and `UPSTREAM-LICENSE` for BSD-3-Clause terms.

It retains the real system-bus `AuthenticationAgent` contract, login-session
registration, administrator identity choice, queued requests, polkit restart
handling, cancellation, and polkit's PAM helper. It does not grant privileges:
the policy authority and its privileged helper decide authorization.

The dialog uses a compact icon-and-message layout, account and protected input
rows, Cancel/OK, and the existing CutefishToolkit native window. Labels and the
legacy layout were compared with the installed Apple SecurityAgent resource
archive. No authentication was triggered on the Mac. This is not a verified
pixel-identical reproduction of a live Tahoe authentication window. The lock SVG
is our own artwork, not an Apple resource.

Local changes require BeginAuthentication and CancelAuthentication to come from
the current unique owner of `org.freedesktop.PolicyKit1`, reject malformed user
identities, recognize exact helper success/failure records, reject a failed
helper exit, and bound helper records. Raw helper diagnostics are not logged.
The field and undo state clear immediately after submission and cancellation;
our response buffers are overwritten after handoff. Toolkit, allocator and
kernel copies cannot be guaranteed erased. No credentials are stored in files,
settings, process arguments or logs.

Build through the parent Cutefish CMake project on Linux. The image stages only
the agent binary, source, license, and icon. `cutefish/session.py` starts this
agent in place of the stock one; it does not change polkit policies or PAM.

Validation executables are separate from the installed agent:

* `makos-auth-protocol-test` checks pure parsing and sender rules.
* `makos-auth-session-test` runs temporary unprivileged fixture scripts through
  real pipes. Its fixed fake inputs never reach polkit/PAM.
* `makos-auth-dialog-test ICON OUTPUT.png` uses the toolkit's headless platform
  to exercise text entry, masking, submission, retry, clearing and Escape. It
  creates no agent listener or PAM session; the capture contains fixture labels.

The complete system-bus/PAM authorization path needs an installed Linux session
test with the user. A successful fixture is not real authentication evidence.
