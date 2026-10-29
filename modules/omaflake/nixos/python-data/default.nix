# SPDX-License-Identifier: MIT
# Module: python-data – Python for analysis: numpy, pandas, matplotlib, JupyterLab
{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.python3.withPackages (ps: with ps; [ numpy pandas matplotlib jupyterlab ]))
  ];
}
