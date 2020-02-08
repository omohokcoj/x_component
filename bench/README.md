### Environment:

```
Operating System: macOS
CPU Information: Intel(R) Core(TM) i5-5250U CPU @ 1.60GHz
Number of Available Cores: 4
Available memory: 8 GB
Elixir 1.9.0
Erlang 22.1.4
```

### Compilation:

```
Name                                ips        average  deviation         median         99th %
Floki/Mochi (html parser)        385.79        2.59 ms    ±16.85%        2.46 ms        4.24 ms
X (parser)                       357.78        2.80 ms    ±22.56%        2.60 ms        5.08 ms
EEx (html)                       314.95        3.18 ms    ±21.56%        3.10 ms        5.60 ms
X (compiler)                     152.93        6.54 ms    ±15.52%        6.44 ms        9.80 ms
Calliope (haml)                   23.83       41.97 ms     ±4.77%       41.47 ms       48.87 ms
Slime (slim)                       2.27      441.24 ms    ±14.87%      413.43 ms      582.09 ms
Expug (pug)                      0.0836    11962.34 ms     ±0.00%    11962.34 ms    11962.34 ms

Comparison:
Floki/Mochi (html parser)        385.79
X (parser)                       357.78 - 1.08x slower +0.20 ms
EEx (html)                       314.95 - 1.22x slower +0.58 ms
X (compiler)                     152.93 - 2.52x slower +3.95 ms
Calliope (haml)                   23.83 - 16.19x slower +39.37 ms
Slime (slim)                       2.27 - 170.23x slower +438.65 ms
Expug (pug)                      0.0836 - 4614.95x slower +11959.75 ms
```

### Rendering list:

```
Name                           ips        average  deviation         median         99th %
X (iodata)                  1.13 K      887.73 μs    ±31.50%      819.90 μs     1895.73 μs
Phoenix EEx (iodata)        1.04 K      962.62 μs    ±30.42%      895.90 μs     1956.00 μs
X (string)                  1.01 K      991.42 μs    ±29.17%      915.90 μs     2040.98 μs
Phoenix EEx (string)        0.95 K     1047.88 μs    ±27.30%      979.90 μs     2068.21 μs
EEx (string)                0.69 K     1443.95 μs    ±19.18%     1353.90 μs     2451.34 μs

Comparison:
X (iodata)                  1.13 K
Phoenix EEx (iodata)        1.04 K - 1.08x slower +74.88 μs
X (string)                  1.01 K - 1.12x slower +103.68 μs
Phoenix EEx (string)        0.95 K - 1.18x slower +160.15 μs
EEx (string)                0.69 K - 1.63x slower +556.22 μs
```

### Rendering nested:

```
Name                           ips        average  deviation         median         99th %
X (iodata)                    7.11      140.66 ms    ±11.74%      137.84 ms      192.84 ms
Phoenix EEx (iodata)          6.19      161.49 ms    ±17.79%      154.52 ms      265.19 ms
X (string)                    4.65      215.19 ms    ±13.17%      217.22 ms      292.51 ms
Phoenix EEx (string)          4.29      233.20 ms    ±16.37%      212.74 ms      323.82 ms

Comparison:
X (iodata)                    7.11
Phoenix EEx (iodata)          6.19 - 1.15x slower +20.83 ms
X (string)                    4.65 - 1.53x slower +74.54 ms
Phoenix EEx (string)          4.29 - 1.66x slower +92.55 ms
```

### Rendering inline:

```
Name                           ips        average  deviation         median         99th %
X inline (iodata)          20.38 K       49.06 μs    ±17.15%          47 μs          93 μs
X inline (string)          14.48 K       69.05 μs    ±20.50%          66 μs      134.53 μs
Phoenix EEx (iodata)        7.52 K      133.05 μs    ±15.62%         129 μs         228 μs
Phoenix EEx (string)        6.43 K      155.45 μs    ±13.31%         149 μs         249 μs
X function (iodata)         3.33 K      300.67 μs    ±14.48%         283 μs      487.91 μs
X function (string)         2.79 K      358.93 μs    ±11.44%         343 μs         544 μs

Comparison:
X inline (iodata)          20.38 K
X inline (string)          14.48 K - 1.41x slower +19.99 μs
Phoenix EEx (iodata)        7.52 K - 2.71x slower +83.99 μs
Phoenix EEx (string)        6.43 K - 3.17x slower +106.39 μs
X function (iodata)         3.33 K - 6.13x slower +251.60 μs
X function (string)         2.79 K - 7.32x slower +309.86 μs
```
