using Workerd = import "/workerd/workerd.capnp";
const config :Workerd.Config = (
  services = [
    (name = "edge-test", worker = (
      modules = [
        (name = "test", esModule = embed "identity-workerd.mjs"),
        (name = "edge/identity-gate.mjs", esModule = embed "../edge/identity-gate.mjs")
      ],
      compatibilityDate = "2026-11-02",
      compatibilityFlags = ["global_fetch_strictly_public"],
      globalOutbound = "synthetic-identity"
    )),
    (name = "synthetic-identity", worker = (
      modules = [(name = "authority", esModule = embed "identity-workerd-authority.mjs")],
      compatibilityDate = "2026-11-02"
    ))
  ]
);
