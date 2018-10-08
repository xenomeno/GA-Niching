Niching in Genetic Algorithm for Multimodal Function Optimization

Multi-modal function with equal peaks:
![](Niche/GA_Niching_Equal.gif?raw=true "")

Multi-modal function with decreasing in magnitude peaks:
![](Niche/GA_Niching_Decreasing.gif?raw=true "")

Implementation is in Lua 5.3 and is based on David E. Goldberg's book "Genetic Algorithms: In Search, Optimization and Machine Learning".

As can be seen "No sharing" concentrates all population members on a single peak even though they are of same magnitude(92th generation):
![](Niche/EqualPeaks_0092.bmp?raw=true "")

On the decreasing version they are spread proportionaly to the peak magnitude when sharing function is used and they are stable when advancing(88th generation):
![](Niche/DecreasingPeaks_0088.bmp?raw=true "")

With the crowding factor in the beginning different peaks are identified but advancing the generations tends the population to concentrate on a single peak again.

Algorithm uses standard Roulette Wheel Selection, Singe-Point Crossover for binary strings and very small binary mutation rate. De Jong's Crowding Factor of 3 is used with population gap G=0.1 and triangular sharing function with Sigma Share=0.1.


No improvements are made in the algorithm like fitness scaling, ranking, overlapping population, crowd factoring and so on. Only the simple  implementation is tested. The results are saved in a bitmap file which is implemented in pure Lua and is quite slow though.




