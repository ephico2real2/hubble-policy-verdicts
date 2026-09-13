#!/usr/bin/env python3
"""check-dashboard.py <assembled dashboard JSON> with-row|without — the contract CI holds the rendered dashboard to.

Every line here came from a review or a released fix; the reason is beside it. Run by .github/workflows/ci.yml on the
JSON Helm renders (with the Loki row and without), and by hand: helm template … | … > /tmp/d.json && python3 hack/check-dashboard.py /tmp/d.json with-row
"""
import collections, json, sys

d = json.load(open(sys.argv[1])); mode = sys.argv[2]
panels = d['panels']; tv = d['templating']['list']
def targets(p): return json.dumps(p.get('targets', []))

if mode == 'with-row':
    assert any(p.get('type') == 'row' and 'Loki' in p.get('title', '') for p in panels), 'the Loki row (0.2.0)'
    assert any(v['name'] == 'DS_LOKI' for v in tv), 'the Loki datasource variable'
    assert any(v['name'] == 'cf2cnpURL' and v['query'] == 'https://cf2cnp.test' for v in tv), 'cf2cnpURL from values'
    assert '${cf2cnpURL}/generate' in json.dumps(d), 'the Generate action'
    t = next(p for p in panels if p.get('type') == 'table' and 'Flow UUID' in p.get('title', ''))
    org = next(x for x in t['transformations'] if x['id'] == 'organize')
    assert org['options']['excludeByName'].get('Line') is not True, 'Line must stay in the frame for the action body'
    assert any(o['matcher'].get('options') == 'Line' and any(pr['id'] == 'custom.hideFrom.viz' for pr in o['properties']) for o in t['fieldConfig']['overrides']), 'Line hidden from the viz, as dashboard 23862 does'
    rows_sorted = [p['title'].split()[0] for p in sorted((p for p in panels if p['type'] == 'row'), key=lambda p: p['gridPos']['y'])]
    assert rows_sorted == ['1', '2', '3', '4', '5', '6', 'Dropped'], ('the sections in visual order, the Loki row last', rows_sorted)
else:
    assert not any(v['name'] == 'DS_LOKI' for v in tv), 'no Loki variable without the row'

assert any(v['name'] == 'role' and v['type'] == 'custom' for v in tv), 'the role variable (0.2.1)'
non_dns = [p for p in panels if 'hubble_dns_' not in targets(p)]
assert not any(s in targets(p) for p in non_dns for s in ('source_namespace=~', 'destination_namespace=~')), 'every query goes through ${role} (the DNS section excepted, 0.3.0; review 0.4.0 C2)'
dns = [p for p in panels if p['type'] != 'row' and 'hubble_dns_' in targets(p)]
assert dns and not any('${role}' in targets(p) for p in dns), 'the DNS section names the namespace as the asking side, not through role (0.3.0)'
assert not any('demo' in (p.get('title', '') + p.get('description', '')).lower() for p in panels), 'no PoC wording in a released panel (0.2.2)'
assert 'kubecon' not in json.dumps(d).lower(), 'no kubecon tag or wording (0.3.0)'
rows = [p['title'].split()[0] for p in panels if p['type'] == 'row']
assert rows[:6] == ['1', '2', '3', '4', '5', '6'], ('six numbered sections in document order', rows)

# 0.4.0 layout contract (review C8, C9): four tiles per section, h4 w6 for the new ones (section 1 keeps its 0.2.2 h5), unique ids
c = collections.Counter(); ri = 0
for p in panels:
    if p['type'] == 'row': ri += 1
    elif p['type'] == 'stat': c[ri] += 1
assert [c[i] for i in range(1, 7)] == [4, 4, 4, 4, 4, 4], ('four tiles per section', dict(c))
assert all(p['gridPos']['h'] == 4 and p['gridPos']['w'] == 6 for p in panels if p['type'] == 'stat' and p['id'] > 8), 'the 0.4.0 tiles are h4 w6'
assert len({p['id'] for p in panels}) == len(panels), 'unique panel ids'
lines = collections.defaultdict(list)
for p in panels: lines[p['gridPos']['y']].append(p)
for y, ps in lines.items():
    spans = sorted((p['gridPos']['x'], p['gridPos']['x'] + p['gridPos']['w']) for p in ps)
    assert all(spans[i][1] <= spans[i + 1][0] for i in range(len(spans) - 1)), ('overlap at y', y)
    assert all(0 <= a and b <= 24 for a, b in spans), ('outside the grid at y', y)

# 0.4.0 semantics (review C1, C3, C6)
assert all('destination_namespace' in t['expr'] for p in panels if p['title'].startswith(('TCP:', 'ICMP:')) for t in p['targets'][1:]), 'replies matched by identity AND namespace (review C1)'
assert all('or on (source, source_namespace) 0 *' in t['expr'] for p in panels if p['title'].startswith(('TCP:', 'ICMP:', 'DNS:')) for t in p['targets'][2:]), 'a sender with no reply series is zero-filled, not dropped (review C1, Codex)'
assert all('or on (source, source_namespace) 0 *' in p['targets'][0]['expr'] and p['targets'][0]['expr'].startswith('sum(clamp_min(') for p in panels if p['title'].startswith('Missing ') and p['type'] == 'stat'), 'the missing tiles clamp per sender, then sum (review C1)'
alert = {'Dropped in range', 'Drops in range', 'Policy drops in range', 'Other reasons in range', 'Missing SYN-ACKs in range', 'Missing echo replies in range', 'Missing answers in range', 'Errors in range', '5xx in range'}
for p in panels:
    if p['title'] in alert:
        f = p['fieldConfig']['defaults']; assert f['decimals'] == 1 and f['thresholds']['steps'][1]['value'] == 1e-9, ('alert tile colours any positive value (review C6)', p['title'])
assert next(v['allValue'] for v in tv if v['name'] == 'namespace') == '.+', '"All" is every namespace, not the unattributed endpoints (review C2)'
non_dns_exprs = [t['expr'] for p in non_dns for t in p.get('targets', []) if 'expr' in t]
assert all('${role}=~"$namespace"' in e for e in non_dns_exprs), 'every non-DNS query carries the role matcher (review C9)'
lr = next(p for p in panels if p['type'] == 'row' and 'Loki' in p['title']) if mode == 'with-row' else None
if lr:
    li = panels.index(lr); assert li == len(panels) - 2 and panels[-1]['datasource']['type'] == 'loki', 'the Loki row and its table close the document'
    assert max(p['gridPos']['y'] + p['gridPos']['h'] for p in panels[:li]) <= lr['gridPos']['y'], 'nothing reaches under the Loki row (review C9)'
for i, a in enumerate(panels):
    A = a['gridPos']
    for b in panels[i + 1:]:
        B = b['gridPos']
        assert not (max(A['x'], B['x']) < min(A['x'] + A['w'], B['x'] + B['w']) and max(A['y'], B['y']) < min(A['y'] + A['h'], B['y'] + B['h'])), ('two panels overlap', a['title'], b['title'])
assert 'not a unique-flow count' in next(p['description'].lower() for p in panels if p['title'] == 'Flow events in range'), 'the flows tile says it counts events per node (review C3)'
assert all('decimals' not in p['fieldConfig']['defaults'] for p in panels if p['title'] in ('p50 latency', 'p99 latency')), 'latency tiles let Grafana scale s to ms/µs (review C6)'
assert all('reporter="server"' in t['expr'] for p in panels if 'hubble_http_' in targets(p) for t in p['targets']), 'HTTP counted once, server-reported'
print(mode + ':', len(panels), 'panels, contract holds')
