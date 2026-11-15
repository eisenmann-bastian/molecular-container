import pymol
from pymol import cmd

pymol.finish_launching(["pymol", "-cq"])

cmd.load("/work/molecule.sdf", "molecule")
cmd.hide("everything", "all")
cmd.show("sticks", "molecule")
cmd.bg_color("white")
cmd.orient("molecule")
cmd.png("/work/molecule.png", width=1200, height=900, dpi=150, ray=1)

cmd.quit()
