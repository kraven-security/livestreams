"""Use the MCP SDK to exercise real stdio tools, without a hosted LLM."""
import asyncio
import os
import json
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
root = Path(__file__).resolve().parents[1]
async def main():
    for name in ('MISP_URL', 'MISP_API_KEY'):
        if not os.getenv(name):
            raise SystemExit(f'Set {name} first.')
    os.environ['MISP_VERIFYCERT'] = 'true'
    params = StdioServerParameters(
        command=str(root / 'repos/misp-mcp/.venv/bin/misp-mcp'), env=dict(os.environ))
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            names = sorted(t.name for t in (await session.list_tools()).tools)
            print('Available tools:', ', '.join(names))
            result = await session.call_tool('search_event_index', {
                'eventinfo': 'Part12 synthetic incident', 'limit': 5, 'page': 1})
            if result.isError:
                raise SystemExit('MCP tool returned an error; inspect off-screen.')
            payload = getattr(result, 'structuredContent', None)
            if isinstance(payload, dict) and 'result' in payload:
                payload = payload['result']
            if payload is None:
                blocks = [b.text for b in result.content if hasattr(b, 'text')]
                decoded = [json.loads(text) for text in blocks]
                # FastMCP v1 emits one text block per list entry.
                payload = decoded[0] if len(decoded) == 1 and isinstance(decoded[0], list) else decoded
            if isinstance(payload, dict):
                if any(k in payload for k in ('errors', 'error', 'message')):
                    raise SystemExit('MISP returned an error inside the tool result; inspect off-screen.')
                payload = [payload] if 'info' in payload or 'Event' in payload else payload.get('response', [])
            if isinstance(payload, list) and any(
                isinstance(row, dict) and any(k in row for k in ('errors', 'error', 'message'))
                for row in payload
            ):
                raise SystemExit('MISP error inside result; inspect off-screen.')
            if not isinstance(payload, list) or not payload:
                raise SystemExit('No matching events returned. Check read-only user visibility; this is not a passed check.')
            matching = []
            for row in payload:
                e = row.get('Event', row) if isinstance(row, dict) else {}
                if 'Part12 synthetic incident' in str(e.get('info', '')):
                    matching.append({'id': e.get('id'), 'info': e.get('info')})
            if not matching:
                raise SystemExit('No expected Part12 event found in response.')
            print('PASS: matching synthetic event metadata:', json.dumps(matching, indent=2))
async def bounded_main():
    try:
        await asyncio.wait_for(main(), timeout=45)
    except TimeoutError:
        raise SystemExit('MCP check timed out after 45 seconds; use the fallback.')
asyncio.run(bounded_main())
