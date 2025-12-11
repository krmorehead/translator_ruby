function LoadingIndicator() {
  return (
    <div className="loading-indicator" role="status" aria-live="polite">
      <span className="dot" />
      <span className="dot" />
      <span className="dot" />
      <span className="label">Thinking...</span>
    </div>
  );
}

export default LoadingIndicator;


