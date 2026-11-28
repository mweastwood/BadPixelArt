/// Computes a deterministic pseudo-random floating point value in the range [0.0, 1.0]
/// based on 2D coordinates [x], [y] and an integer [seed].
double hashNoise(int x, int y, int seed) {
  int n = x * 374761393 + y * 668265263 + seed * 1274126177;
  n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff;
  n = n ^ (n >> 16);
  return (n & 0x7fffffff) / 0x7fffffff;
}
