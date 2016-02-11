options(bitmapType='cairo')

args <- commandArgs(TRUE)
dir<-args[1]
inputFile<-args[2]
distanceCutoff<-args[3]

setwd(dir)

pngfile<-paste(inputFile,".png",sep='')
png(pngfile,height=800,width=600)

par(mfrow=c(2,1))

myData<-read.table(inputFile,header=T,sep="\t")

myData<-subset(myData,myData$plotFlag == 1)

plotFlag<-myData$plotFlag
distance<-myData$distance
topStrand<-myData$topStrand
bottomStrand<-myData$bottomStrand
inward<-myData$inward
outward<-myData$outward
sameStrand<-myData$sameStrand

inwardRatio<-myData$inwardRatio
outwardRatio<-myData$outwardRatio
difference<-myData$difference

allX<-c(distance,distance,distance,distance)
allY<-c(topStrand,bottomStrand,inward,outward)
ymax<-max(allY)
ymin<-min(allY)
# first plot

plot(allX,allY,type="n",ylab="percent of reads per strand/strand",xlab="distance (1kb bins)",main=paste("nearby strand bias","\n","excluding distance <= ",distanceCutoff,sep=""))

lines(distance,topStrand,col="red",lwd=3)
lines(distance,bottomStrand,col="pink",lwd=3)
lines(distance,inward,col="green",lwd=3)
lines(distance,outward,col="blue",lwd=3)

abline(h=25,col="black",lwd=1,lty=2)

rect(0, ymin, distanceCutoff, ymax, col=rgb(1,0,0,0.1),border=rgb(1,0,0,0.1))
abline(v=distanceCutoff,col=rgb(0.5,0.5,0.5),lwd=1)

legend("topright", legend = c("topStrand","bottomStrand","inward","outward"),lwd=3,xjust=1,col=c("red","pink","green","blue"),yjust=1)

# second plot

allX<-c(distance,distance,distance)
allY<-c(inwardRatio,outwardRatio,difference)
ymax<-max(allY)
ymin<-min(allY)
ymax<-max(c(abs(ymax),abs(ymin)))
ymin<--(ymax)

plot(allX,allY,type="n",ylab="ratio of read percent",xlab="distance (1kb bins)",ylim=c(ymin,ymax),main=paste("nearby strand bias","\n","excluding distance <= ",distanceCutoff,sep=""))

lines(distance,inwardRatio,col="green",lwd=3)
lines(distance,outwardRatio,col="blue",lwd=3)
lines(distance,difference,col="black",lwd=3)

abline(h=0,col="black",lwd=1,lty=2)

rect(0, -ymax, distanceCutoff, ymax, col=rgb(1,0,0,0.1),border=rgb(1,0,0,0.1))
abline(v=distanceCutoff,col=rgb(0.5,0.5,0.5),lwd=1)

legend("topright", legend = c("inward / sameStrand","outward / sameStrand","difference from sameStrand"),lwd=3,xjust=1,col=c("green","blue","black"),yjust=1)

dev.off()