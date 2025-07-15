# Introduction to using snpArcher on Della

All credit to Brian Arnold -- this is adapted from his excellent ["Intro to Comp Bio Workflows" workshop](https://github.com/brian-arnold/intro_compbio_workflows_2024) he gave here in early 2024. If you're just getting started working on Della or doing bioinformatics, I highly recommend looking through all of the readmes in his workshop -- it's a great intro! 

snpArcher has been updated several times since Brian gave this workshop. These updates broke some things, and changes to the pipeline are not always super well documented, so I've modified the instructions for day 3 of his workshop.

**Last update:** July 15, 2025

These instructions assume you have some general knowledge of the Della cluster, using conda, scripting, and command line tools, as well as the general concept behind snpArcher and what it's used for. If you don't, days 1 and 2 of Brian's workshop will be very helpful with getting you up to speed. Additionally, take a look at [the snpArcher paper](https://academic.oup.com/mbe/article/41/1/msad270/7466717)!


### Overview of included guides
01_getting_data: Provides info on how to download sequencing data or a reference genome on Della

02_running_snparcher: Tutorial for running snpArcher on Della

03_how_it_works: More info on the architecture of the pipeline and what's happening in key rules

