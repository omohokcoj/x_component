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
Floki/Mochi (html parser)        392.71        2.55 ms    ±11.62%        2.45 ms        3.63 ms
X (parser)                       381.84        2.62 ms    ±17.63%        2.43 ms        4.11 ms
EEx (html)                       349.64        2.86 ms    ±15.52%        2.70 ms        4.32 ms
X (compiler)                     167.53        5.97 ms    ±10.33%        6.12 ms        7.76 ms
Calliope (haml)                   20.74       48.21 ms     ±9.94%       47.57 ms       60.01 ms
Slime (slim)                       2.28      438.06 ms    ±15.21%      410.57 ms      607.55 ms
Expug (pug)                      0.0842    11873.28 ms     ±0.00%    11873.28 ms    11873.28 ms

Comparison:
Floki/Mochi (html parser)        392.71
X (parser)                       381.84 - 1.03x slower +0.0725 ms
EEx (html)                       349.64 - 1.12x slower +0.31 ms
X (compiler)                     167.53 - 2.34x slower +3.42 ms
Calliope (haml)                   20.74 - 18.93x slower +45.67 ms
Slime (slim)                       2.28 - 172.03x slower +435.51 ms
Expug (pug)                      0.0842 - 4662.76x slower +11870.73 ms
```

### Rendering list:

```
Name                           ips        average  deviation         median         99th %
X (iodata)                  1.49 K      668.91 μs    ±15.19%      639.90 μs     1129.82 μs
X (string)                  1.31 K      762.65 μs    ±13.15%      730.90 μs     1271.20 μs
Phoenix EEx (iodata)        1.04 K      957.73 μs    ±30.40%      892.90 μs     2013.72 μs
Phoenix EEx (string)        0.94 K     1061.82 μs    ±27.92%      991.90 μs     2181.32 μs
EEx (string)                0.71 K     1410.01 μs    ±17.44%     1324.90 μs     2421.37 μs

Comparison:
X (iodata)                  1.49 K
X (string)                  1.31 K - 1.14x slower +93.74 μs
Phoenix EEx (iodata)        1.04 K - 1.43x slower +288.82 μs
Phoenix EEx (string)        0.94 K - 1.59x slower +392.91 μs
EEx (string)                0.71 K - 2.11x slower +741.10 μs
```

### Rendering nested:

```
Name                           ips        average  deviation         median         99th %
X (iodata)                    8.71      114.76 ms    ±10.96%      113.07 ms      158.93 ms
X (string)                    6.43      155.51 ms    ±12.95%      148.41 ms      214.75 ms
Phoenix EEx (iodata)          6.25      160.12 ms    ±17.66%      153.37 ms      249.08 ms
Phoenix EEx (string)          4.32      231.63 ms    ±17.09%      215.29 ms      327.41 ms

Comparison:
X (iodata)                    8.71
X (string)                    6.43 - 1.36x slower +40.76 ms
Phoenix EEx (iodata)          6.25 - 1.40x slower +45.36 ms
Phoenix EEx (string)          4.32 - 2.02x slower +116.87 ms
```

### Rendering inline:

```
Name                           ips        average  deviation         median         99th %
X inline (iodata)          13.48 K       74.19 μs    ±18.28%       71.90 μs      137.90 μs
X inline (string)           9.18 K      108.93 μs    ±24.44%      105.90 μs      208.90 μs
Phoenix EEx (iodata)        7.51 K      133.19 μs    ±64.53%      125.90 μs      233.90 μs
Phoenix EEx (string)        6.20 K      161.31 μs    ±17.02%      154.90 μs      275.49 μs
X function (iodata)         2.62 K      380.97 μs    ±18.36%      355.90 μs      647.51 μs
X function (string)         2.25 K      444.03 μs    ±16.29%      417.90 μs      728.80 μs

Comparison:
X inline (iodata)          13.48 K
X inline (string)           9.18 K - 1.47x slower +34.73 μs
Phoenix EEx (iodata)        7.51 K - 1.80x slower +58.99 μs
Phoenix EEx (string)        6.20 K - 2.17x slower +87.11 μs
X function (iodata)         2.62 K - 5.13x slower +306.78 μs
X function (string)         2.25 K - 5.98x slower +369.84 μs
```
