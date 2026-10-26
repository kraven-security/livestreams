"""Use the MCP SDK to exercise real stdio tools, without a hosted LLM."""
import asyncio
import os
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
root = Path(__file__).resolve().parents[1]
async def main():
    for name in ('MISP_URL', 'MISP_API_KEY'):
        if not os.getenv(name):
            raise SystemExit(f'Set {name} first.')
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
            for block in result.content:
                if hasattr(block, 'text'):
                    print(block.text)
asyncio.run(main())
