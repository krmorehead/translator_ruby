function AgentInspector({ agentState }) {
  const statePayload = agentState?.state || {};
  const inventory = statePayload.inventory || [];
  const memories = statePayload.memories || {};
  const version = agentState?.version ?? 0;

  return (
    <div className="agent-inspector">
      <header>
        <p className="eyebrow">Agent Inspector</p>
        <h3>Version {version}</h3>
      </header>

      <section>
        <h4>Memory Sections</h4>
        <div className="inspector-grid">
          {Object.entries(memories).map(([key, value]) => (
            <div className="inspector-card" key={key}>
              <p className="label">{key}</p>
              <pre>{JSON.stringify(value, null, 2)}</pre>
            </div>
          ))}
          {Object.keys(memories).length === 0 && (
            <p className="muted">No memory data loaded yet.</p>
          )}
        </div>
      </section>

      <section>
        <h4>Inventory</h4>
        {inventory.length === 0 ? (
          <p className="muted">Inventory is empty.</p>
        ) : (
          <ul className="inventory-list">
            {inventory.map((item, idx) => (
              <li key={idx}>
                <strong>{item.name}</strong>
                {item.quantity != null && <span> × {item.quantity}</span>}
                {item.description && <p className="muted">{item.description}</p>}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

export default AgentInspector;

