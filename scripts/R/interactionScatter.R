options(bitmapType='cairo')

args <- commandArgs(TRUE)
dir<-args[1]
name<-args[2]

setwd(dir)

pngfile<-paste(name,".png",sep='')
png(pngfile,height=600,width=600)

if((file.info(name)[[1]][1]) > 0) {
	scatter<-read.table(name,header=F,sep="\t")
	x<-scatter[,1]
	y<-scatter[,2]

	y2<-y
	y2<-sort(y2)
	ysize<-length(y2)
	ysize<-floor(ysize*.998)
	ysize<-y2[ysize]

	scatter.sorted <- scatter[order(scatter$V1) , ]
	x<-scatter.sorted[,1]
	y<-scatter.sorted[,2]
	
	plot(x,y,ylim=c(0,ysize),col=rgb(0.25,0.25,0.25,0.5),main="5C Scatter Plot",xlab="Genomic Distance (bp)",ylab="5C Counts",cex=0.5)
	ma100 = c(rep(1, 100))/100;
	y.smoothed<-filter(y,ma100)
	lines(x,y.smoothed,col="red")
} else {
	plot(0,0,main="ERROR - Found 0 valid reads, cannot draw scatter plot")
}

dev.off()