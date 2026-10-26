# Presenter talking points — Part 12

Read these as short cues. The Google Doc has the full steps and timing.

## misp-scraper

- Start with a report; keep its source and context.
- The scraper creates a MISP event and report, then asks MISP to extract indicators.
- Extraction must be enabled; a created event alone is not a finished import.
- Review every candidate: extracted does not mean malicious.
- Try one report in a lab before automating feeds.

## CTI-Transmute

- Use it when two tools need different threat-intelligence formats.
- Today we convert MISP to STIX and back using synthetic data.
- Check diagnostics and compare values, types and relationships.
- A successful HTTP response does not prove a lossless conversion.
- The public service receives your input; self-host for restricted data.

## misp-mcp

- MCP gives a compatible client structured tools for querying MISP.
- This MISP implementation is read-only.
- We show a real tool call over stdio; the demo does not need a hosted LLM.
- Keep queries bounded and check event IDs against the source.
- Read-only access still needs permissions and careful data handling.

## Fleet Commander

- One interface helps you inspect several MISP instances.
- Start with health, version and connection visibility.
- Check timestamps: a green response is not a complete health assessment.
- Bulk actions are powerful; today we only inspect the lab.
- Try two lab instances before managing a larger fleet.

## misp-guard

- Guard inspects MISP synchronization traffic against configured policies.
- Rules can consider tags, distribution levels, compartments and data types.
- A blocked event should stop before it reaches its destination.
- Today’s passing tests prove selected mocked decisions, not a deployed network.
- A real deployment must also test TLS trust, routing and bypass prevention.

