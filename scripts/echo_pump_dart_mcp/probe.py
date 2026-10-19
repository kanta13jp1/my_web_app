"""Exercise the SDK-shipped Dart MCP via real stdio, retaining every response."""
import asyncio
import json
import os
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from mcp.types import ListRootsResult, Root

ROOT = Path.cwd()
OUT = ROOT / 'dart-mcp-evidence'
OUT.mkdir(exist_ok=True)

def save(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf8')

async def roots(_):
    return ListRootsResult(roots=[Root(uri=ROOT.as_uri(), name='echo-pump-test-checkout')])

async def main():
    versions = {}
    for command in [['dart', '--version'], ['flutter', '--version'], ['dart', 'mcp-server', '--help']]:
        result = subprocess.run(command, capture_output=True, text=True)
        versions[' '.join(command)] = {'code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
    save('environment.json', {'utc': datetime.now(timezone.utc).isoformat(), 'sha': os.environ.get('GITHUB_SHA'), 'versions': versions})
    args = ['mcp-server']
    # The pinned SDK decides what is available; do not assume current main's CLI.
    help_text = versions['dart mcp-server --help']['stdout']
    if '--force-roots-fallback' in help_text:
        args.append('--force-roots-fallback')
    if '--enable' in help_text:
        args += ['--enable', 'run_tests,dart_format']
    save('launch.json', {'command': 'dart', 'args': args, 'transport': 'stdio', 'client': 'Python MCP SDK 1.26.0'})
    with (OUT / 'server-stderr.log').open('w', encoding='utf8') as err:
        async with stdio_client(StdioServerParameters(command='dart', args=args), errlog=err) as streams:
            async with ClientSession(*streams, list_roots_callback=roots) as session:
                init = await session.initialize()
                save('initialize.json', init.model_dump(mode='json'))
                tool_list = await session.list_tools()
                save('tools.json', tool_list.model_dump(mode='json'))
                tools = {tool.name: tool for tool in tool_list.tools}
                calls = []
                async def call(name, arguments):
                    start=time.monotonic()
                    result = await session.call_tool(name, arguments, read_timeout_seconds=__import__('datetime').timedelta(minutes=6))
                    entry={'name':name,'arguments':arguments,'seconds':round(time.monotonic()-start,3),'result':result.model_dump(mode='json')}
                    calls.append(entry)
                    save('calls.json', calls)
                    print(json.dumps({'name':name,'isError':result.isError,'seconds':entry['seconds']},ensure_ascii=False),flush=True)
                    return result
                if 'add_roots' in tools:
                    await call('add_roots', {'roots':[{'uri':ROOT.as_uri(),'name':'echo-pump-test-checkout'}]})
                elif 'roots' in tools:
                    await call('roots', {'command':'add','roots':[{'uri':ROOT.as_uri(),'name':'echo-pump-test-checkout'}]})
                # Discover schema first; follow-up uses exact paths and test contracts.
                if 'analyze_files' in tools:
                    await call('analyze_files', {'roots':[{'root':ROOT.as_uri(),'paths':['lib/pages/echo_pump_game_page.dart','lib/widgets/echo_pump_title_screen.dart']}]})
                if 'resolve_workspace_symbol' in tools:
                    await call('resolve_workspace_symbol', {'query':'EchoPumpGame'})
                tests = await call('run_tests', {'roots':[{'root':ROOT.as_uri(),'paths':['test/widgets/echo_pump_title_screen_test.dart','test/pages/echo_pump_restart_test.dart']}], 'testRunnerArgs':{'concurrency':'1','reporter':'expanded'}})
                output = '\n'.join(getattr(c,'text','') for c in tests.content)
                passed = 'All tests passed!' in output and 'Some tests failed.' not in output
                stage = os.environ.get('DART_MCP_STAGE', 'baseline')
                save('summary.json', {'stage':stage,'tools':len(tools),'calls':len(calls),'mcpErrors':sum(bool(c['result'].get('isError')) for c in calls),'testsPassed':passed,'sha':os.environ.get('GITHUB_SHA')})
                if stage == 'baseline':
                    assert not passed and 'Bad state: No element' not in output
                    assert output.count('Found 0 widgets with text') == 4, output
                else:
                    assert passed, output

asyncio.run(main())
