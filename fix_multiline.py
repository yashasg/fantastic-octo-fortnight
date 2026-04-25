#!/usr/bin/env python3
"""Fix multiline_arguments SwiftLint violations.

Two patterns:
1. First arg on same line as ( in multiline call → move to next line
2. Multiple args on same line in multiline call → split to one per line

Also fixes vertical_parameter_alignment_on_call by using consistent indentation.
"""
import sys
import subprocess
import os


def get_violation_lines(filepath):
    """Get multiline_arguments violation line numbers from swiftlint."""
    result = subprocess.run(
        ['swiftlint', 'lint', filepath],
        capture_output=True, text=True,
        cwd='/Users/yashasgujjar/dev/fantastic-octo-fortnight'
    )
    violations = set()
    for line in (result.stdout + result.stderr).splitlines():
        if 'multiline_arguments' in line or 'vertical_parameter_alignment_on_call' in line:
            parts = line.split(':')
            if len(parts) >= 2:
                try:
                    violations.add(int(parts[1]))
                except ValueError:
                    pass
    return violations


def find_matching_close(text, start, open_ch='(', close_ch=')'):
    depth = 0
    in_string = False
    escape = False
    i = start
    while i < len(text):
        ch = text[i]
        if escape:
            escape = False
            i += 1
            continue
        if ch == '\\' and in_string:
            escape = True
            i += 1
            continue
        if ch == '"':
            in_string = not in_string
        elif not in_string:
            if ch == open_ch:
                depth += 1
            elif ch == close_ch:
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    return -1


def split_top_level_args(text):
    """Split by top-level commas outside strings and nested parens."""
    args = []
    current = []
    depth = 0
    in_string = False
    escape = False
    
    for ch in text:
        if escape:
            current.append(ch)
            escape = False
            continue
        if ch == '\\' and in_string:
            current.append(ch)
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            current.append(ch)
            continue
        if in_string:
            current.append(ch)
            continue
        if ch in '([{':
            depth += 1
            current.append(ch)
        elif ch in ')]}':
            depth -= 1
            current.append(ch)
        elif ch == ',' and depth == 0:
            args.append(''.join(current))
            current = []
        else:
            current.append(ch)
    
    if current:
        args.append(''.join(current))
    return args


def contains_multiline_inner_call(arg_text):
    """Check if an arg contains a nested function call that itself spans multiple lines."""
    # If the arg text contains a newline inside a nested paren, it's multiline
    depth = 0
    in_string = False
    escape = False
    for ch in arg_text:
        if escape:
            escape = False
            continue
        if ch == '\\' and in_string:
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        elif ch == '\n' and depth > 0:
            return True
    return False


def reformat_call(text, open_pos, base_indent):
    """Reformat a function call at open_pos. Returns (new_text, close_pos) or None."""
    close_pos = find_matching_close(text, open_pos)
    if close_pos == -1:
        return None
    
    inner = text[open_pos + 1:close_pos]
    
    # Check if it's actually multiline
    if '\n' not in inner:
        return None
    
    # Normalize whitespace while preserving strings
    inner_norm = ' '.join(inner.split())
    
    # Split into args
    args = split_top_level_args(inner_norm)
    args = [a.strip() for a in args]
    
    if not args or (len(args) == 1 and not args[0]):
        return None
    
    # Check if any arg contains a multiline inner call
    # If so, we need to handle it specially
    arg_indent = ' ' * (base_indent + 4)
    
    new_parts = ['(\n']
    for j, arg in enumerate(args):
        # Check if this arg has a nested multiline call
        if '(' in arg and contains_multiline_inner_call_from_normalized(arg):
            # This arg has a nested call that should be multiline
            # We'll handle it by reconstructing it properly
            pass
        
        if j < len(args) - 1:
            new_parts.append(arg_indent + arg + ',\n')
        else:
            new_parts.append(arg_indent + arg + ')')
    
    return (''.join(new_parts), close_pos)


def contains_multiline_inner_call_from_normalized(arg):
    """For a normalized (single-line) arg, check if it has a nested call with many args."""
    # If it contains a nested call with multiple args, it might need to be multiline
    # But since we normalized it, we don't know. We'll let the recursive pass handle it.
    return False


def process_file(filepath, max_iters=100):
    """Process file iteratively until no more violations."""
    total_fixed = 0
    for iteration in range(max_iters):
        violations = get_violation_lines(filepath)
        if not violations:
            break
        
        with open(filepath, 'r') as f:
            lines = f.readlines()
        
        changed = False
        
        # For each violation line, find the enclosing function call and reformat it
        # Process from bottom to top
        sorted_violations = sorted(violations, reverse=True)
        
        for v_line in sorted_violations:
            li = v_line - 1  # 0-indexed
            if li < 0 or li >= len(lines):
                continue
            
            line = lines[li]
            
            # Find the opening ( that causes this violation
            # It could be on this line or a previous line
            # Strategy: search backward for the opening ( of the enclosing call
            
            # First check if THIS line has a ( with content after it
            # that continues to the next line
            open_col = find_violation_open_paren(lines, li)
            
            if open_col is not None:
                target_line, target_col = open_col
                result = reformat_call_in_lines(lines, target_line, target_col)
                if result:
                    new_lines, end_line = result
                    lines[target_line:end_line + 1] = new_lines
                    changed = True
                    break  # Restart after each change
        
        if changed:
            with open(filepath, 'w') as f:
                f.writelines(lines)
            total_fixed += 1
        else:
            break
    
    return total_fixed > 0


def find_violation_open_paren(lines, violation_line):
    """Find the ( that causes a multiline_arguments violation on the given line.
    Returns (line_idx, col_idx) or None."""
    
    # Case 1: The violation line itself has a ( with content and continues
    line = lines[violation_line]
    in_string = False
    escape = False
    paren_positions = []
    
    for i, ch in enumerate(line):
        if escape:
            escape = False
            continue
        if ch == '\\' and in_string:
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch == '(':
            paren_positions.append(i)
        elif ch == ')':
            if paren_positions:
                paren_positions.pop()
    
    # Check each unmatched ( on this line
    for paren_col in paren_positions:
        after = line[paren_col + 1:].strip()
        if after:
            # Check if call is multiline
            close = find_close_paren_in_lines(lines, violation_line, paren_col)
            if close and close[0] > violation_line:
                return (violation_line, paren_col)
    
    # Case 2: The ( is on a previous line and this line has multiple args
    # Search backward for the enclosing (
    for search_line in range(violation_line - 1, max(violation_line - 10, -1), -1):
        sl = lines[search_line]
        in_str = False
        esc = False
        parens = []
        for i, ch in enumerate(sl):
            if esc:
                esc = False
                continue
            if ch == '\\' and in_str:
                esc = True
                continue
            if ch == '"':
                in_str = not in_str
                continue
            if in_str:
                continue
            if ch == '(':
                parens.append(i)
            elif ch == ')':
                if parens:
                    parens.pop()
        
        for paren_col in parens:
            close = find_close_paren_in_lines(lines, search_line, paren_col)
            if close and close[0] >= violation_line:
                return (search_line, paren_col)
    
    return None


def find_close_paren_in_lines(lines, start_line, start_col):
    """Find matching ) given ( at lines[start_line][start_col]."""
    depth = 0
    in_string = False
    escape = False
    
    for li in range(start_line, len(lines)):
        line = lines[li]
        start = start_col if li == start_line else 0
        for ci in range(start, len(line)):
            ch = line[ci]
            if escape:
                escape = False
                continue
            if ch == '\\' and in_string:
                escape = True
                continue
            if ch == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
                if depth == 0:
                    return (li, ci)
    return None


def reformat_call_in_lines(lines, open_line, open_col):
    """Reformat a function call. Returns (new_lines, end_line) or None."""
    close = find_close_paren_in_lines(lines, open_line, open_col)
    if close is None:
        return None
    
    close_line, close_col = close
    
    if open_line == close_line:
        return None  # Single line, no fix needed
    
    # Get prefix (everything up to and including open paren)
    prefix = lines[open_line][:open_col + 1]
    base_indent = len(lines[open_line]) - len(lines[open_line].lstrip())
    arg_indent = ' ' * (base_indent + 4)
    
    # Collect content between parens
    content_parts = []
    for li in range(open_line, close_line + 1):
        line = lines[li]
        if li == open_line:
            content_parts.append(line[open_col + 1:].rstrip('\n'))
        elif li == close_line:
            content_parts.append(line[:close_col].rstrip('\n'))
        else:
            content_parts.append(line.rstrip('\n'))
    
    inner = ' '.join(part.strip() for part in content_parts if part.strip())
    
    # Split into top-level args
    args = split_top_level_args(inner)
    args = [a.strip() for a in args if a.strip()]
    
    if not args:
        return None
    
    # Check what's after the closing paren on that line
    after_close = lines[close_line][close_col + 1:].rstrip('\n')
    
    # Build new lines
    new_lines = [prefix.rstrip() + '\n']
    for j, arg in enumerate(args):
        if j < len(args) - 1:
            new_lines.append(arg_indent + arg + ',\n')
        else:
            new_lines.append(arg_indent + arg + ')' + after_close + '\n')
    
    return (new_lines, close_line)


def main():
    if len(sys.argv) < 2:
        print("Usage: fix_multiline.py <file1.swift> ...")
        sys.exit(1)
    
    for filepath in sys.argv[1:]:
        print(f"Processing: {filepath}")
        if process_file(filepath):
            remaining = get_violation_lines(filepath)
            if remaining:
                print(f"  {len(remaining)} violations remain")
            else:
                print(f"  All fixed!")
        else:
            print(f"  No violations")


if __name__ == '__main__':
    main()
