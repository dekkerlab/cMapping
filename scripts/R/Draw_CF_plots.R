# USAGE: Rscript scripts/Draw_CF_plots.R /home/gjain/bin/projects/mapping/ output_mapped_files/July_11_2012-2iterativeMapping.stats test 25 36 5 testLog.txt
options(bitmapType='cairo')

userWarnings     <- warnings();
args             <- commandArgs(TRUE);
wd               <- args[1];
inputName        <- args[2];
iterationStart   <- args[3];
iterationEnd     <- args[4];
iterationStep    <- args[5];
setwd(wd);

############### USER DEFINED FUNCTIONS #####################
# Draw plots
draw_graphs <- function() {
	# all plots on one page
	par(mfrow=c(2,2)) 

	# Draw one separate graph for each dataset in one plot
	heading<-c("Total Reads","Zero Aligned Reads","Exactly 1 Aligned Reads",">1 Aligned Reads")

	#Draw the box plots for (total_reads,0-aligned,>1-aligned) 
	draw_box_plot("Total Reads", s1TotalReads,s2TotalReads, s1iter);
	draw_box_plot("Zero Aligned Reads", ZeroAlignedS1reads,ZeroAlignedS2reads, s1iter);
	draw_box_plot(">1 Aligned Reads", MultipleAlignedS1reads,MultipleAlignedS2reads, s1iter);

	# # draw the Cumulative Frequency Plot for the Exact 1 aligned reads
	plot(OneCumSumS1,main="Exactly 1 Aligned Reads",xlab="Trimmed Read Length (bp)",ylab="Cumulative (%) Mapped Reads", ylim=c(0,100), cex.axis=0.8, col=plot_colors[1], type="o", axes=FALSE, lwd=2);
	lines(OneCumSumS2, cex.axis=0.8, col=plot_colors[2], type="o",lwd=2);
	axis(1, at=1:length(s1iter), lab=c(s1iter));axis(2);
	box(lty = "solid", col = NA);
	# add a legend 
	legend("topright",c("Side 1 Reads","Side 2 Reads"),col=plot_colors, fill=plot_colors, , bty="l", ncol=1, cex=0.85)
	
	devOut <- dev.off();
}

draw_box_plot <- function(mtitle, s1, s2, siter) {
	# Axes
	xlabel = "Trimmed Read Length (bp)";
	ylabel = "Number of reads";
	ylimit = max(s1,s2)+ max(s1,s2)*0.1;
	
	plot(s1 ,xlab=xlabel, ylab=ylabel,main=mtitle, cex.axis=0.8, col=plot_colors[1], type="o", axes=FALSE, lwd=2, ylim=c(0,ylimit));
	lines(s2,xlab=xlabel, ylab=ylabel,main=mtitle, cex.axis=0.8, col=plot_colors[2], type="o",lwd=2);

	# Make x axis using labels
	axis(1, at=1:length(siter), lab=c(siter));
	axis(2);
	box(lty = "solid", col = NA);

	# add a legend 
	legend("topright",c("Side1 Reads","Side2 Reads"),col=plot_colors, fill=plot_colors, , bty="l", ncol=1, cex=0.85);
}

# Draw the error plots with the error messages.
draw_error_plots <- function (mtitle) {
	plot(0,xaxt='n',yaxt='n',bty='n',pch='',ylab='',xlab='');
	box(lty = "solid", col = "red");

	# add a legend 
	# par(fg="white"); # make the font white;
	legend("center", mtitle, col="red", bg="red", bty="l", cex=1.5);
}
 
# Create the png fileinputName
pngfile<-paste(inputName,".png",sep='')
# Start PNG device driver to save output to figure.png
png(pngfile,height=800,width=800)

############################################ MAIN ##############################################

# getting the file inputName
inputfile <- paste(inputName,sep='');

# Read values from tab-delimited input file
	# Side	Iteration	TOTALreads	ZeroAlignedNo	OneAlignedNo	OnePlusAlignedNo	OneMinusAlignedNo	MultipleAlignedNo	ZeroAlignedPc	OneAlignedPc	OnePlusAlignedPc	OneMinusAlignedPc	MultipleAlignedPc
	# 1	25	25000	5151	19443	6966	12477	406	20.60	77.77	27.86	49.91	1.62
	# 1	30	5557	3960	1151	535	616	446	71.26	20.71	9.63	11.09	8.03
	# 2	25	25000	5587	18587	11957	6630	826	22.35	74.35	47.83	26.52	3.30
	# 2	30	6413	4299	1220	752	468	894	67.04	19.02	11.73	7.30	13.94
	data <- read.table(inputfile,header=T,sep="\t");

## Validate data
maxIter <- max(data$Iteration);
erroriterationEnd <- 0;
if(maxIter != iterationEnd){
	erroriterationEnd <- 1 ;
	etitle <- c("ERROR: LAST ITERATION DOESNT MATCH WITH INPUT LAST ITERATION",paste("\t- Expected = ",maxIter),paste("\t- Entered   = ",iterationEnd));
	draw_error_plots(etitle);
	quit();
}

# get the index
s1rowindex        <- (1:nrow(data))[data$Side==1];
s1dataunsorted    <- data[s1rowindex,];
s1data            <- s1dataunsorted[sort.list(s1dataunsorted$Iteration), ]
s1firstIterIndex  <- (1:nrow(s1data))[s1data$Iteration==iterationStart];
FirstS1TotalReads <- s1data[s1firstIterIndex,]$TOTALreads; # 25000

s2rowindex        <- (1:nrow(data))[data$Side==2];
s2dataunsorted    <- data[s2rowindex,];
s2data            <- s2dataunsorted[sort.list(s2dataunsorted$Iteration), ]
s2firstIterIndex  <- (1:nrow(s2data))[s2data$Iteration==iterationStart];
FirstS2TotalReads <- s2data[s2firstIterIndex,]$TOTALreads; # 25000

# If the first total read number don`t match then set the error flag
errorFirstTotalReads <- 0;
if(FirstS1TotalReads != FirstS2TotalReads){
	errorFirstTotalReads <- 1 ;
	etitle <- c("ERROR: READS NUMBER DO NOT MATCH",paste("\t- First Side1 Total Reads = ",FirstS1TotalReads),paste("\t- First Side2 Total Reads = ",FirstS2TotalReads));
	draw_error_plots(etitle);
	quit();
}

# Get the relevant read data
# Side1
s1TotalReads <- s1data$TOTALreads 
ZeroAlignedS1reads <- s1data$ZeroAlignedNo
ZeroAlignedS1readsPC <- round(((ZeroAlignedS1reads/s1TotalReads)*100),3)
OneAlignedS1reads  <- s1data$OneAlignedNo
OneAlignedS1readsPC  <- round(((OneAlignedS1reads/s1TotalReads)*100),3)
MultipleAlignedS1reads <- s1data$MultipleAlignedNo
MultipleAlignedS1readsPC <- round(((MultipleAlignedS1reads/s1TotalReads)*100),3)
s1iter <-s1data$Iteration
# Side2
s2TotalReads <- s2data$TOTALreads 
ZeroAlignedS2reads <- s2data$ZeroAlignedNo
OneAlignedS2reads  <- s2data$OneAlignedNo
MultipleAlignedS2reads <- s2data$MultipleAlignedNo
s2iter <-s2data$Iteration


# Get the relevant read percentages
# Side1
OneAlignedS1Pc <- OneAlignedS1reads*100/FirstS1TotalReads;
OneCumSumS1 <- cumsum(OneAlignedS1Pc);
# Side2
OneAlignedS2Pc <- OneAlignedS2reads*100/FirstS2TotalReads;
OneCumSumS2 <- cumsum(OneAlignedS2Pc);

# Define colors to be used for different parameters
plot_colors   <- c(rgb(0.4, 0.6, 0.8,0.9),rgb(1.0, 0.4, 0.2,0.9));
legend_colors <- c(rgb(0.4, 0.6, 0.8),rgb(1.0, 0.4, 0.2));

# Draw the stats graphs;
draw_graphs();

#======== uncomment this to get the pdf of the plots =========#
# # Create the pdf fileinputName
# pdffile<-paste(inputName".pdf",sep='')
# # Start PDF device driver to save output to figure.pdf
# pdf(pdffile)
# draw_graphs()