# Broadband Inversion Pulse Generator

This directory contains an `awk` script
that generates broadband inversion pulses (BIP)
for Varian/Agilent systems.

```
usage: awk -f makeBIP.awk bip.dat ref_pwr ref_pw90
ref_pwr in dB, ref_pw90 in us
```
