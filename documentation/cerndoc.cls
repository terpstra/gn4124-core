%Documentation class
%Simon DEPREZ

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{cerndoc}[2010/03/20 cern documentation, V0.1]
 
% classe de base
\LoadClassWithOptions{article}
%\setlength\paperheight {297mm}  % A4 paper
%\setlength\paperwidth  {210mm}
 
% extensions
\RequirePackage[utf8]{inputenc}
\RequirePackage[T1]{fontenc}
\RequirePackage{lmodern}
\RequirePackage[pdftex]{graphicx}
\RequirePackage{geometry}
\RequirePackage{fancyhdr}
\RequirePackage{tikz}
\RequirePackage{tabularx}

\RequirePackage{lastpage}
\RequirePackage{parskip}
\RequirePackage{listings}

\RequirePackage[colorlinks=true,linkcolor=black ,urlcolor=green!60!blue]{hyperref}



% Times
\RequirePackage{mathptmx}
\RequirePackage[scaled=.90]{helvet}
\RequirePackage{courier}

\newcommand\CernDocSection[1]{\renewcommand{\@CernDocSection}{#1}}
\newcommand\CernDocType[1]{\renewcommand{\@CernDocType}{#1}}
\newcommand\CernDocTitle[1]{\renewcommand{\@CernDocTitle}{#1}}
\newcommand\CernDocEditedBy[1]{\renewcommand{\@CernDocEditedBy}{#1}}
\newcommand\CernDocCheckedBy[1]{\renewcommand{\@CernDocCheckedBy}{#1}}
\newcommand\CernDocDate[1]{\renewcommand{\@CernDocDate}{#1}}
\newcommand\CernDocAbstract[1]{\renewcommand{\@CernDocAbstract}{#1}}
\newcommand{\@CernDocSection}{CERN Section}
\newcommand{\@CernDocType}{Functional Specification for}
\newcommand{\@CernDocTitle}{Title}
\newcommand{\@CernDocDate}{}
\newcommand{\@CernDocAbstract}{. . .}
\newcommand{\@CernDocEditedBy}{Author}
\newcommand{\@CernDocCheckedBy}{}

\geometry{ hmargin=3.0cm, vmargin=3.8cm }	
\graphicspath{{images/}}
\DeclareGraphicsExtensions{.jpg,.png,.pdf}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\fancyhf{}
\headheight=15pt
%\footheight=50pt
\renewcommand{\headrulewidth}{1.4pt}
\renewcommand{\footrulewidth}{1.4pt}
\fancyhead[L]{\@CernDocTitle}
\fancyhead[R]{
\begin{tikzpicture}[remember picture, overlay]
  %\node at (current page.center) {\includegraphics[width=15cm]{logoDRAFT}}; 
\end{tikzpicture}
}
\fancyfoot[R]{\small Page \thepage{} of \pageref{LastPage}}
\fancyfoot[L]{\small{\@CernDocSection}}
\pagestyle{fancy}

\newcommand{\cerntitle}{%
\begin{titlepage}
\begin{tikzpicture}[remember picture, overlay]
    \definecolor{cernblue}{RGB}{0,20,170}
      \node[minimum width=17cm,minimum height=24.7cm,rectangle, rounded corners=5pt
,draw,color=cernblue,line width=3pt] at (current page.center){};
      \node[shift={(-6.1cm,10cm)}] at (current page.center) {\includegraphics[width=3.5cm]{logoCERN}};
      \node[shift={(1.8cm,10cm)}] at (current page.center) {%
         \begin{minipage}[t]{13cm}
            \centering
            \fontsize{12}{12}\selectfont
         	\textbf{\textsc{Organisation Européenne pour la Recherche Nucléaire}\\
			\textsc{European Organization for Nuclear Research}}\\
			\bigskip
            \fontsize{20}{20}\selectfont
			\@CernDocSection\\
         \end{minipage}
      };      

\end{tikzpicture}

\vspace*{6cm}
{\Huge\@CernDocType}

\medskip
{\Huge\@CernDocTitle}

\bigskip
\fontsize{14}{14}\selectfont\@CernDocDate

\vspace*{2cm}
\begin{minipage}[c]{.46\linewidth}
  \textbf{Edited by:} 
  
  \medskip
  {\large\@CernDocEditedBy}
\end{minipage} \hfill
\begin{minipage}[c]{.46\linewidth}
  \textbf{Checked by:} 
  
  \medskip
  {\large\@CernDocCheckedBy}
\end{minipage}

\vspace*{2cm}
\begin{abstract}
	\noindent\@CernDocAbstract
\end{abstract}

\end{titlepage}
}