#!/bin/bash

set -e

echo "========================================"
echo " Loading QuestaSim"
echo "========================================"

module load mentor/questasim/2023.4_5 


echo "========================================"
echo " Starting simulation"
echo "========================================"

vsim -do run.do
