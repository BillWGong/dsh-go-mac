export function Ticker() {
  const items = ['TRACE', 'DIFF', 'FILES', 'PROGRESS', 'CONTEXT', 'THE RUN IS THE INTERFACE'];
  const row = [...items, ...items, ...items];
  return (
    <div className="ticker" aria-hidden>
      <div className="ticker-track">
        {row.map((t, i) => <span key={`${t}-${i}`}>{t}{i < row.length - 1 && <i> ◆ </i>}</span>)}
      </div>
    </div>
  );
}
