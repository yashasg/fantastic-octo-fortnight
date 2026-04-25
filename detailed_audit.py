#!/usr/bin/env python3
import yaml
import glob
import re

workflows = sorted(glob.glob('.github/workflows/*.{yml,yaml}'))
findings = {}

print("=" * 80)
print("COMPREHENSIVE CI/CD WORKFLOW AUDIT")
print("=" * 80)
print()

for workflow_path in workflows:
    wf_name = workflow_path.split('/')[-1]
    findings[wf_name] = []
    
    with open(workflow_path, 'r') as f:
        content = f.read()
        workflow = yaml.safe_load(content)
    
    # 1. Required top-level fields
    if not workflow.get('name'):
        findings[wf_name].append("Missing 'name' field")
    if not workflow.get('on'):
        findings[wf_name].append("Missing 'on' (trigger) field")
    if not workflow.get('jobs'):
        findings[wf_name].append("Missing 'jobs' field")
    
    # 2. Check jobs have 'runs-on' and 'steps'
    jobs = workflow.get('jobs', {})
    for job_name, job in jobs.items():
        if not job.get('runs-on') and not job.get('if'):
            findings[wf_name].append(f"Job '{job_name}': missing 'runs-on' or conditional")
        if not job.get('steps'):
            findings[wf_name].append(f"Job '{job_name}': missing 'steps'")
        
        # Check each step has a name
        steps = job.get('steps', [])
        for i, step in enumerate(steps):
            if not step.get('name'):
                findings[wf_name].append(f"Job '{job_name}', step {i}: missing 'name' field")
    
    # 3. Check for actual hardcoded secrets (not references)
    # Look for lines with password/token but NOT using ${{ ... }}
    lines = content.split('\n')
    for i, line in enumerate(lines, 1):
        # Skip comments
        if line.strip().startswith('#'):
            continue
        # Look for suspicious patterns
        if re.search(r'(password|secret|token|api_key|bearer)\s*[:=]\s*["\']?[a-zA-Z0-9]{8,}', line):
            if not re.search(r'\$\{\{.*\}\}', line):
                findings[wf_name].append(f"Line {i}: Potential hardcoded credential: {line.strip()}")
    
    # 4. Check for outdated action versions
    outdated_actions = re.findall(r'uses:\s+(\S+@v[0-3](?:\.\d+)*)', content)
    if outdated_actions:
        findings[wf_name].append(f"Outdated actions detected: {', '.join(outdated_actions)}")
    
    # 5. Check for unresolved TODOs
    todos = re.findall(r'#.*(?:TODO|FIXME|XXX|PLACEHOLDER|stub)', content)
    for todo in todos:
        findings[wf_name].append(f"TODO/FIXME found: {todo.strip()}")
    
    # 6. Verify script references
    scripts = re.findall(r'\./scripts/(\S+)', content)
    import os
    for script in set(scripts):
        script_path = f'scripts/{script}'
        if not os.path.exists(script_path):
            findings[wf_name].append(f"Referenced script not found: {script_path}")

# Print results
print()
for wf_name in sorted(findings.keys()):
    issues = findings[wf_name]
    status = "✓ PASS" if not issues else f"✗ FAIL ({len(issues)} issue(s))"
    print(f"{wf_name:30} {status}")
    for issue in issues:
        print(f"  → {issue}")
    if not issues:
        print()

print()
print("=" * 80)
total_issues = sum(len(issues) for issues in findings.values())
if total_issues == 0:
    print("✓ VERDICT: CONVERGED — All workflows passed comprehensive audit")
else:
    print(f"✗ VERDICT: {total_issues} ISSUE(S) FOUND")
print("=" * 80)
