PY := .venv/bin/python

.PHONY: all venv sim analyze package quartus synth synth-all clean

all: sim analyze

venv: .venv/.done
.venv/.done: requirements.txt
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt
	touch $@

# Regenerate the VHDL package (also done by run.py)
package: venv
	$(PY) -m model.design

# Bit-exact + latency tests in all four configurations; writes doc/results.md
sim: venv
	$(PY) run.py -p 4

# Filter figures, the latency/quality summary and the latency result plots
analyze: venv
	$(PY) -m model.analyze
	$(PY) -m model.plot_results

# DE10-Nano bitstream (needs Intel Quartus Prime)
quartus:
	quartus_sh -t boards/de10nano/build.tcl

# Optional: resource/timing numbers for one configuration with Vivado: make synth T=1 M=1
T ?= 1
M ?= 1
synth:
	vivado -mode batch -nojournal -nolog -source syn/build.tcl -tclargs $(T) $(M)

synth-all:
	$(MAKE) synth T=0 M=0
	$(MAKE) synth T=1 M=1

clean:
	rm -rf build vunit_out
