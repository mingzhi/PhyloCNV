#!/usr/bin/env Rscript

suppressPackageStartupMessages(library("argparse"))
suppressPackageStartupMessages(library("RColorBrewer"))

# functions
get_script_dir <- function(){
	args <- commandArgs(trailingOnly = F)
	scriptDir <- normalizePath(dirname(sub("^--file=", "", args[grep("^--file=", args)])))
	return(scriptDir)
}

# specify our desired options
parser <- ArgumentParser()
parser$add_argument("-v", "--verbose", action="store_true", default=TRUE,
	help="Print extra output [default]")
parser$add_argument("-i", type="character", required=T, dest="inpath",
	help="Path to matrix of species relative abundances or coverage",
	metavar="filepath")
parser$add_argument("-m", type="character", required=T, dest="metapath",
	help="Path to tab-delimited metadata file. Should contain at least two columns. The first column are sample ids. The remaining columns are categorical variables.",
	metavar="filepath")
parser$add_argument("-o", type="character", required=T, default=1, dest="outpath",
	help="Path to output PDF",
	metavar="filepath")
parser$add_argument("-f", type="integer", default=1, dest="field",
	help="Column number in metadata file to use for plotting; 1 indicates the first non-sample-id field [1]",
	metavar="number")
parser$add_argument("-c", type="double", default=0, dest="cutoff",
	help="Cutoff to use for determining species prevalence. Indicates genome coverage if '-i' is a coverage matrix; indicates relative abundance if '-i' is an abundance matrix [0]",
	metavar="number")
parser$add_argument("-n", type="integer", default=20, dest="nspecies",
	help="Number of species to display in plot [20]",
	metavar="number")
parser$add_argument("-p", action="store_true", default=F, dest="prop",
	help="Display y-axis as a proportion instead of count")

# get command line options
args <- parser$parse_args()

# print some progress messages to stderr if "quietly" wasn't requested
if ( args$verbose ) {
	write("Making species prevalence boxplot...", stderr())
}

# read input data
abun_df <- read.csv(args$inpath, sep='\t', row.names=1, check.names=F, stringsAsFactors=F)
meta_df <- read.csv(args$metapath, sep='\t', row.names=1, check.names=F, stringsAsFactors=F)
species_df <- read.csv(paste(get_script_dir(),'../ref_db/annotations.txt',sep='/'), sep='\t', row.names=1)

# compute species prevalence
species_ids <- rownames(abun_df)
group_ids <- unique(meta_df[,args$field])
prev_mat <- matrix(nrow=length(group_ids), ncol=length(species_ids))
colnames(prev_mat) <- species_ids
rownames(prev_mat) <- group_ids
for (group_id in group_ids){
	sample_values <- meta_df[,args$field]
	sample_indexes <- which(sample_values==group_id)
	sample_ids <- row.names(meta_df)[sample_indexes]
	for (species_id in species_ids){
		prevalence <- length(which(abun_df[species_id, sample_ids] >= args$cutoff))
		if (args$prop) prevalence <- prevalence/length(sample_ids)
		prev_mat[group_id, species_id] <- prevalence
	}
}
prev_mat <- prev_mat[,order(-colSums(prev_mat))]


# make barplot of prevalence for top n most prevalent species
pdf(args$outpath, width=26, height=12)

par(mar=c(28,12,8,1))
par(mgp=c(4,1,0))
space <- 0.4

species_ids <- colnames(prev_mat)[seq(args$nspecies)]
species_names <- species_df[species_ids, 'consensus_name']
species_labels <- paste(species_names, paste('(',species_ids,')', sep=''), sep=' ')

group_ids <- unique(meta_df[,args$field])
ngroups <- length(group_ids)
colors <- brewer.pal(max(3, ngroups), 'Spectral')[seq(ngroups)]
data <- prev_mat[rev(row.names(prev_mat)), species_ids]

barplot(
	data,
	col=rev(colors),
	xaxt='n',
	cex.axis=2.7,
	cex.lab=2.7,
	ylab="Species Prevalence",
	space=space,
	ylim=c(0, 1.5 * max(apply(prev_mat, 2, sum)))
)

axis(
	side=1,
	at=seq(1, args$nspecies+(args$nspecies*space), 1+space),
	labels=species_labels,
	las=2,
	cex.axis=1.5
	)

legend(
	'topright',
	legend=group_ids,
	fill=colors,
	title=names(meta_df)[args$field],
	cex=2.5,
	ncol=2
)

# make boxplot of species abundance for top n most prevalent species
boxplot(
	t(abun_df[species_ids, ]),
	use.cols = TRUE,
	col='blue',
	xaxt='n',
	cex.axis=2.7,
	cex.lab=2.7,
	ylab="Species Abundance",
	frame=F
)

axis(
	side=1,
	at=seq(1, args$nspecies),
	labels=species_labels,
	las=2,
	cex.axis=1.5
)

dev.off()




