<img height=40 src='http://my5C.umassmed.edu/images/3DG.png' title='3D-Genome' />
&nbsp;&nbsp;
<img height=30 src='http://my5C.umassmed.edu/images/dekkerlabbioinformatics.gif' />
&nbsp;&nbsp;
<img height=30 src='http://my5C.umassmed.edu/images/umasslogo.gif' />

# cMapping

mapping pipeline for 5C/Hi-C experiments

```
stage1 wrapper
    processFlowCell.pl - map lane from Illumina Sequencer (PE)
    
stage2 wrapper
    combineHiC.pl - combine, bin, filter and balance Hi-C data
    combine5C.pl - combine 5C data
```

## Installation

cMapping requires numpy/h5py

You can install the dependencies with:
```
for req in $(cat requirements.txt); do pip install $req; done
```

cMapping also requires the following git repos

https://github.com/blajoie/cMapping
https://github.com/blajoie/hdf2tab
https://github.com/blajoie/tab2hdf
https://github.com/blajoie/balance

cMapping also requires a 'genome' directory containing FASTA, Bowtie2 Indices and a 'restrictionFragment' for each genome/enzyme combination.
A pre-comupted genome directory can be downloaded here:
https://www.dropbox.com/s/1if5hctt7n5b0xl/genome.tar.gz?dl=0

## Communication

- [Bryan Lajoie](https://github.com/blajoie)
- [Noam Kaplan](https://github.com/NoamKaplan)
- Twitter: [@my5C](https://twitter.com/my5C)

## What does it do?

?

## Usage


### processFlowCell
```
$ perl ~/git/cMapping/scripts/utilities/processFlowCell.pl 

Tool:           processFlowCell.pl
Version:        1.0.6
Summary:        cMapping pipeline - stage 1

Usage: perl processFlowCell.pl [OPTIONS] -i <inputFlowCellDirectory> -o <outputDirectory> --gdir <genomeDirectory>

Required:
        -i         []         flow cell directory (path)
        -s         []         scratch directory (path)
        -o         []         output directory (path)
        --gdir     []         genome directory (fasta,index,restrictionSite)

Options:
        -v         []         FLAG, verbose mode
        --log      []         log directory
        --email    []         user email address
        --split    []         splitSize, # reads per chunk
        -g         []         genomeName, genome to align
        -e         []         enzyme name (DpnII, HindIII etc.)
        -h         []         FLAG, hic flag 
        -f         []         FLAG, 5C flag
        -d         []         FLAg, debugMode - keep all files for debug purposes
        --ks       []         FLAG, keep sam files
        --short    []         FLAG, use the short queue
        --sm       []         FLAG, snpMode - allelic Hi-C

Notes:
    Stage 1 of the cMapping pipeline, for processing 5C/Hi-C data [UMMS specific].

Contact:
    Bryan R. Lajoie
    Dekker Lab 2016
    https://github.com/blajoie/cMapping
    https://github.com/blajoie/cWorld-dekker
    http://my5C.umassmed.edu
```

### combineHiC
```
$ perl ~/git/cMapping/scripts/utilities/combineHiC.pl 

Tool:           combineHiC.pl
Version:        1.0.6
Summary:        cMapping pipeline - stage 2 [Hi-C]

Usage: perl combineHiC.pl [OPTIONS] -i <inputCDataDirectory> -o <outputDirectory> --gdir <genomeDirectory>

Required:
        -i         []         cData directory(path)
        -s         []         scratch directory (path)
        -o         []         output directory (path)
        --gdir     []         genome directory (fasta,index,restrictionSite)
        -g         []         genomeName, genome to align

Options:
        -v         []         FLAG, verbose mode
        -e         []         enzyme name (DpnII, HindIII etc.)
        --log      []         log directory
        --email    []         user email address
        -d         []         FLAg, debugMode - keep all files for debug purposes
        --short    []         FLAG, use the short queue

Notes:
    Stage 2 of the cMapping pipeline, for processing 5C/Hi-C data [UMMS specific].

Contact:
    Bryan R. Lajoie
    Dekker Lab 2016
    https://github.com/blajoie/cMapping
    https://github.com/blajoie/cWorld-dekker
    http://my5C.umassmed.edu
```

### combine5C
```
$ perl ~/git/cMapping/scripts/utilities/combine5C.pl 

Tool:           combine5C.pl
Version:        1.0.6
Summary:        cMapping pipeline - stage 2 [5C]

Usage: perl combine5C.pl [OPTIONS] -i <inputCDataDirectory> -o <outputDirectory> --gdir <genomeDirectory>

Required:
        -i         []         flow cell directory (path)
        -s         []         scratch directory (path)
        -o         []         output directory (path)
        --gdir     []         genome directory (fasta,index,restrictionSite)

Options:
        -v         []         FLAG, verbose mode
        --log      []         log directory
        --email    []         user email address
        -g         []         genomeName, genome to align
        -d         []         FLAg, debugMode - keep all files for debug purposes
        --short    []         FLAG, use the short queue

Notes:
    Stage 2 of the cMapping pipeline, for processing 5C/Hi-C data [UMMS specific].

Contact:
    Bryan R. Lajoie
    Dekker Lab 2016
    https://github.com/blajoie/cMapping
    https://github.com/blajoie/cWorld-dekker
    http://my5C.umassmed.edu   
```
  
## Usage Examples


```

perl ~/git/cMapping/scripts/utilities/processFlowCell.pl -i ~/farline/HPCC/cshare/solexa/08MAY20_PE50_SAMPLEDATA/ --gdir ~/genome/ -o ~/farline/HPCC/cshare/ --log ~/cshare/cWorld-logs/ -s ~/scratch -g dm3 -h 

```

## Change Log

## Bugs and Feedback

For bugs, questions and discussions please use the [Github Issues](https://github.com/blajoie/hdf2tab/issues).

## LICENSE

Licensed under the Apache License, Version 2.0 (the 'License');
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an 'AS IS' BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


