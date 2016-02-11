options(bitmapType='cairo')

args <- commandArgs(TRUE)
workDir<-args[1]
inputFile<-args[2]
label<-args[3]

setwd(workDir)

pngfile<-paste(name,".png",sep='')
png(pngfile,height=600,width=600)

if((file.info(inputFile)[[1]][1]) > 0) {
	data<-read.table(inputFile,header=F,sep="\t")
	x<-data[,1]
	y<-data[,2]

	y2<-y
	y2<-sort(y2)
	ysize<-length(y2)
	ysize<-floor(ysize*.98)
	ysize<-y2[ysize]
	
	x2<-x
	x2<-sort(x2)
	xsize<-length(x2)
	xsize<-floor(xsize*.998)
	xsize<-x2[xsize]

	plot(x,y,ylim=c(0,ysize),xlim=c(0,xsize),col=rgb(0.25,0.25,0.25,0.5),main=paste("Distance to RS site - ",label),xlab="Genomic Distance (bp)",ylab="# occurances",cex=0.5)
	#ma100 = c(rep(1, 100))/100;
	#y.smoothed<-filter(y,ma100)
	#lines(x,y.smoothed,col="red")
} else {
	plot(0,0,main="ERROR - Found 0 valid reads, cannot draw scatter plot")
}

dev.off()