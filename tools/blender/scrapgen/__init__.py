"""Procedural scrap-robot component generator for Blender.

Five interchangeable categories -- head, torso, arm, weapon, leg -- generated from
seeds, socketed to a fixed contract, and exported as GLB for a game engine.

Read `sockets.py` first. It is the contract that makes the kit modular, and every
other module in here exists to serve it or to check it.

Entry point: `tools/blender/scrap_robot_generator.py`.
"""

__all__ = ["config", "rng", "materials", "primitives", "greeble", "sockets",
           "component", "registry", "assembly", "exporter", "validate"]
