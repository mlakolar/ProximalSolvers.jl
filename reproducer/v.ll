define <2 x float> @vconv(<2 x i64> %a) {
  %r = sitofp <2 x i64> %a to <2 x float>
  ret <2 x float> %r
}
define float @sconv(i64 %a) {
  %r = sitofp i64 %a to float
  ret float %r
}
