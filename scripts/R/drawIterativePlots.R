options(bitmapType='cairo')

warnings()
args <- commandArgs(TRUE)
name<-args[1]

###############
# getting the file name

inputfile<-paste(name,sep='')

# Read values from tab-delimited input file
	# Side	Iteration	TOTALreads	ZeroAlignedNo	OneAlignedNo	OnePlusAlignedNo	OneMinusAlignedNo	MultipleAlignedNo	ZeroAlignedPc	OneAlignedPc	OnePlusAlignedPc	OneMinusAlignedPc	MultipleAlignedPc
	# 1	25	25000	5151	19443	6966	12477	406	20.60	77.77	27.86	49.91	1.62
	# 1	30	5557	3960	1151	535	616	446	71.26	20.71	9.63	11.09	8.03
	# 2	25	25000	5587	18587	11957	6630	826	22.35	74.35	47.83	26.52	3.30
	# 2	30	6413	4299	1220	752	468	894	67.04	19.02	11.73	7.30	13.94
data<-read.table(inputfile,header=T,sep="\t")

# get the index
s1rowindex<-(1:nrow(data))[data$Side==1]
s1data<-data[s1rowindex,]
FirstS1TotalReads <- s1data[1,]$TOTALreads # 25000

s2rowindex<-(1:nrow(data))[data$Side==2]
s2data<-data[s2rowindex,]
FirstS2TotalReads <- s2data[1,]$TOTALreads # 25000

# Get the relevant read data
# Side1
s1TotalReads <- s1data$TOTALreads 
ZeroAlignedS1reads <- s1data$ZeroAlignedNo
OneAlignedS1reads  <- s1data$OneAlignedNo
MultipleAlignedS1reads <- s1data$MultipleAlignedNo
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
	plot(OneCumSumS1,main="Exactly 1 Aligned Reads",xlab="Truncation length(bp)",ylab="Cumulative frequency (%)", ylim=c(0,110), cex.axis=0.8, col=plot_colors[1], type="o", axes=FALSE, lwd=2);
	lines(OneCumSumS2, cex.axis=0.8, col=plot_colors[2], type="o",lwd=2);
	axis(1, at=1:length(s1iter), lab=c(s1iter));axis(2);
	box(lty = "solid", col = NA);
	# add a legend 
	legend("topright",c("Side1 Reads","Side1 Reads"),col=plot_colors, fill=plot_colors, , bty="l", ncol=1, cex=0.85)
	
	dev.off()
}

draw_box_plot <- function(mtitle, s1, s2, siter) {
	# Axes
	xlabel = "Truncation length(bp)";
	ylabel = "Number of reads";
	ylimit = max(s1,s2)+ max(s1,s2)*0.1;
	
	plot(s1 ,xlab=xlabel, ylab=ylabel,main=mtitle, cex.axis=0.8, col=plot_colors[1], type="o", axes=FALSE, lwd=2, ylim=c(0,ylimit));
	lines(s2,xlab=xlabel, ylab=ylabel,main=mtitle, cex.axis=0.8, col=plot_colors[2], type="o",lwd=2);

	# Make x axis using Mon-Fri labels
	axis(1, at=1:length(siter), lab=c(siter));axis(2);
	box(lty = "solid", col = NA)

	# add a legend 
	legend("topright",c("Side1 Reads","Side1 Reads"),col=plot_colors, fill=plot_colors, , bty="l", ncol=1, cex=0.85)
}

# Create the png filename
pngfile<-paste(name,".png",sep='')
# Start PNG device driver to save output to figure.png
png(pngfile,height=3600,width=3600, res=300)
draw_graphs()

#======== uncomment this to get the pdf of the plots =========#
# # Create the pdf filename
# pdffile<-paste(name".pdf",sep='')
# # Start PDF device driver to save output to figure.pdf
# pdf(pdffile)
# draw_graphs()