#!/bin/bash
# Get a linear regression of an input.
declare -a X=($X)
declare -a Y=($Y)

XMx=()
YMy=()
XMx2=()
YMy2=()

SUMX=0
SUMY=0
for n in ${X[@]}; do
 SUMX=$(echo "$SUMX + $n" | bc)
done

for n in ${Y[@]}; do
 SUMY=$(echo "$SUMY + $n" | bc)
done

if [[ "$SUMX" == "0" || "$SUMY" == "0" ]]; then
 echo "WARNING: Skipping regression comparison, data incomplete.";
 exit 0;
fi

MEANX=$(echo "scale=4; $SUMX / ${#X[@]}" | bc)
MEANY=$(echo "scale=4; $SUMY / ${#Y[@]}" | bc)

for n in ${X[@]}; do
 XMx+=($(echo "$n - $MEANX" | bc))
done

for n in ${Y[@]}; do
 YMy+=($(echo "$n - $MEANY" | bc))
done

# squares sum;
SUMXMx2=0
for n in ${XMx[@]}; do
 XMx2=( $(echo "scale=4; $n * $n" | bc )  )
 SUMXMx2=$(echo "$SUMXMx2 + $XMx2" | bc)
done

# products sum;
SUMXMxYMy=0
for i in ${!XMx[@]}; do
  XMxYMy=( $(echo "scale=4; ${XMx[$i]} * ${YMy[$i]}" | bc) )
  SUMXMxYMy=$(echo "$SUMXMxYMy + $XMxYMy" | bc )
done

SPSSX=$(echo "scale=4; $SUMXMxYMy / $SUMXMx2" | bc)
MybMx=$(echo "scale=4; $MEANY - ($SPSSX * $MEANX)" | bc)

echo "Sum of X = $SUMX"
echo "Sum of Y = $SUMY"
echo "Mean X = $MEANX"
echo "Mean Y = $MEANY"
echo "Sum of squares (SSx) = $SUMXMx2"
echo "Sum of products (SP) = $SUMXMxYMy"
echo "Regression Equation = ŷ = (b)X + a"
echo "b = SP/SSx = $SUMXMxYMy/$SUMXMx2 = $SPSSX"
echo "a = MY - bMX = $MEANY - ($SPSSX * $MEANX) = $MybMx"
echo "ŷ = (${SPSSX})X + $MybMx"

# TODO: confirm what action will be the required if the regression overpass the,
# limit defined;
if [ "$EXPECTED" == "INCREASE" ]; then
  if [ $(echo $SPSSX '<' 0.95 | bc -l) -eq 1 ]; then
    echo "WARNING: Regression > 5%"
  fi
else
  if [ $(echo $SPSSX '>' 1.05 | bc -l) -eq 1 ]; then
    echo "WARNING: Regression > 5%"
  fi
fi
