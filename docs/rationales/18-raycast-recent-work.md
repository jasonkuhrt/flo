## What

Add a dedicated `Recent Flo Work` Raycast command powered by `flo recent --json`.

## Why

Raycast is most compelling when it removes the terminal from simple reentry flows. Recent work is one of the highest-value cases because it usually represents "put me back where I was" rather than "make me browse the full project graph."

## How

The extension now consumes the typed recent-work JSON surface, renders recent items with open/closed state and recency metadata, and reuses `flo open` to perform the actual workspace jump.

## When

Use this from anywhere on macOS when you want the fastest path back into recent work without opening a shell or scanning every workspace.

## Where

The command lives in the Raycast adapter but relies entirely on the shared Flo recent-work surface, which keeps Raycast aligned with the CLI's notion of what is recent and still actionable.
