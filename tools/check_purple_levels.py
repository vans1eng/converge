"""Compatibility entry point for the fixed-clue chapter audit.

To redesign boards, run redesign_clue_levels.py.
"""
from check_clue_levels import audit, cross_check

if __name__ == '__main__':
    cross_check()
    audit()
