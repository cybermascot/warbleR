#' Import Syrinx selections
#' 
#' \code{imp.syrinx} imports Syrinx selection data from many files simultaneously. 
#' All files must be have the same columns.
#' @usage imp.syrinx(path = NULL, all.data = FALSE, recursive = FALSE, 
#' exclude = FALSE, hz.to.khz = TRUE)  
#' @param path A character string indicating the path of the directory in which to look for the text files. 
#' If not provided (default) the function searches into the current working directory. Default is \code{NULL}).
#' @param all.data Logical. If \code{TRUE}) all columns in text files are returned. Default is \code{FALSE}). Note 
#' that all files should contain exactly the same columns in the same order. 
#' @param recursive Logical. If \code{TRUE}) the listing recurse into sub-directories.
#' @param exclude Logical. Controls whether files that cannot be read are ignored (\code{TRUE}). Default is \code{FALSE}.
#' @param hz.to.khz Logical. Controls if frequency variables should be converted from  Hz (the unit used by Syrinx) to kHz (the unit used by warbleR). Default if \code{TRUE}. Ignored if all.data is \code{TRUE}.
#' @return A single data frame with information of the selection files. If all.data argument is set to \code{FALSE}) the data 
#' frame contains the following columns: selec, start, end, and selec.file. If sound.file.col is provided the data frame
#' will also contain a 'sound.files' column. In addition, all rows with duplicated data are removed. This is useful when 
#' both spectrogram and waveform views are included in the Syrinx selection files. If all.data is set to \code{TRUE} then all 
#' columns in selection files are returned.
#' @seealso \code{\link{imp.raven}}
#' @export
#' @name imp.syrinx
#' @examples
#' \dontrun{
#' # First set temporary folder
#' setwd(tempdir())
#' 
#' #load data 
#' data(selection.files)
#' 
#' write.table(selection.files[[3]],file = "harpyeagle.wav.txt",row.names = FALSE,
#'  col.names = FALSE, sep= "\t")
#' 
#' write.table(selection.files[[4]],file = "Phae.long4.wav.txt",row.names = FALSE, 
#' col.names = FALSE, sep= "\t")
#' 
#' syr.dat<-imp.syrinx(all.data = FALSE)
#' 
#' View(syr.dat)
#' 
#' #getting all the data
#' syr.dat<-imp.syrinx(all.data = TRUE)
#' 
#' View(syr.dat)
#' }
#' @author Marcelo Araya-Salas (\email{araya-salas@@cornell.edu})
#last modification on jul-5-2016 (MAS)

imp.syrinx <- function(path = NULL, all.data = FALSE, recursive = FALSE,
                       exclude = FALSE, hz.to.khz = TRUE) 
{ 
  
  # reset working directory 
  wd <- getwd()
  on.exit(setwd(wd))
  
  #check path to working directory
  if(is.null(path)) path <- getwd() else {if(!file.exists(path)) stop("'path' provided does not exist") else
    setwd(path)
  }  

sel.txt <- list.files(full.names = TRUE)
sel.txt2 <- list.files(full.names = FALSE)

sel.txt <- sel.txt[grep(".log$|.txt$",ignore.case = TRUE, sel.txt)]
sel.txt2 <- sel.txt2[grep(".log$|.txt$",ignore.case = TRUE, sel.txt2)]

if(length(sel.txt) == 0) stop("No selection files in working directory/'path' provided")

b<-NULL
if(substring(text = readLines(sel.txt[1])[1], first = 0, last = 9) == "fieldkey:") field <- T else field <- F


clist<-lapply(1:length(sel.txt), function(i)
  {    
  if(field)  {
    
    a <- try(read.table(sel.txt[i], header = TRUE, sep = "\t", fill = TRUE, stringsAsFactors = FALSE), silent = TRUE) 
    if(!exclude & class(a) == "try-error") stop(paste("The selection file",sel.txt[i], "cannot be read"))
    
  if(!class(a) == "try-error" & !all.data) { c <- data.frame(selec.file = sel.txt2[i], sound.files = a[, grep("soundfile",colnames(a))],
                                selec = 1,
                                start = a[, grep("lefttimesec",colnames(a))],
                                end = a[, grep("righttimesec",colnames(a))],
                                low.freq = a[, grep("bottomfreq",colnames(a))],
                                high.freq = a[, grep("topfreq",colnames(a))])
  for(i in 2:nrow(c)) if(c$selec.file[i] == c$selec.file[i-1]) c$selec[i]<-c$selec[i-1] + 1
  } else c<-a 
                                } else {
            a <- try(read.table(sel.txt[i], header = FALSE, sep = "\t", fill = TRUE, stringsAsFactors = FALSE), silent = TRUE) 
            if(!exclude & class(a) == "try-error") stop(paste("The selection file",sel.txt[i], "cannot be read"))
            
            if(!class(a) == "try-error") 
              { 
              c <- a[, seq(2, ncol(a), by =2)]
           colnames(c) <- gsub(":", "", unlist(a[1, seq(1,ncol(a), by =2)]), fixed = TRUE)
           if(!all.data) {c<-data.frame(sound.files = c[, grep("selected",colnames(c), ignore.case = TRUE)],
                                       selec = 1,
                                       start = c[, grep("lefttime",colnames(c), ignore.case = TRUE)],
                                       end = c[, grep("righttime",colnames(c), ignore.case = TRUE)],
                                       low.freq = c[, grep("bottomfreq",colnames(c), ignore.case = TRUE)],
                                       high.freq = c[, grep("topfreq",colnames(c), ignore.case = TRUE)])
           for(i in 2:nrow(c)) if(c$sound.files[i] == c$sound.files[i-1]) c$selec[i] <- c$selec[i-1] + 1} 
           } else c <- a         
                                }
  return(c)
})

clist <- clist[sapply(clist, is.data.frame)]
b <- do.call("rbind", clist)
if(!all.data) if(any(is.na(b$start))) warning("NAs found (empty rows)")

b <- b[!duplicated(b), ]


options(warn = -1)
if(!all.data)
{
  b$start <- as.numeric(b$start)
  b$end <- as.numeric(b$end)

  #remove NA rows
  b <- b[!is.na(b$start), ]
  } else b <-b[b[,2] != names(b)[2],]


# convert to hz
if(hz.to.khz & !all.data & all(c("low.freq", "high.freq") %in% names(b)))
  {b$low.freq <- as.numeric(b$low.freq) / 1000 
  b$high.freq <- as.numeric(b$high.freq) / 1000 
}

  return(b[!duplicated(b), ])

}
