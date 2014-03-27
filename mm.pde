// http://www.societyofrobots.com/member_tutorials/book/export/html/93
import processing.opengl.*;

int X=16; // kolumny
int Y=16; // wiersze
int[] maze = new int[256]; // labirytnt znany, wczytywany z pliku
int[] mapa = new int[256]; // mapa floodfill, przetrzymuje wartosci komorek, zmieniana przez funkcje floodfill
int[] maze_pred = new int[256]; // labirynt rozpoznawany przez mysz
//Dodatki wagowe
int[] mapa_kierunek = new int[256]; //kierunek przejazdu w danej komórce 0 - Brak danych, 1-gora/dol, 2-prawo/lewo
int[] mapa_waga = new int[256];     // zawiera dodatkową wartość przypisaną komórce z racji skrętu
//---------------------------------------------------------------
// simple functions
//---------------------------------------------------------------
boolean isWall(int i, int dir) { return ((maze[i] & dir) != 0); }
//---------------------------------------------------------------
// (MSB) 0 0 0 0 W S E N (LSB)
// N = North Wall Bit (1=exist, 0=no wall)
// E = East Wall Bit (1=exist, 0=no wall)
// S = South Wall Bit (1=exist, 0=no wall)
// W = West Wall Bit (1=exist, 0=no wall)
//---------------------------------------------------------------
int N=1, E=2, S=4, W=8; // bity okreslające sciane 0 - przejazd
int[] DN = {0,-1,16,0,1,0,0,0,-16};
int[] OPPOSITE = {0,S,W,0,N,0,0,0,E};




//---------------------------------------------------------------
/*
1. init hardware
2. init map
3. until goal not achieved
  4. read sensors
  5. update wall map
  6. correct alignment
  7. determine next move
  8. move

OR

(1) Update the wall map
(2) Flood the maze with new distance values
(3) Decide which neighboring cell has the lowest distance value
(4) Move to the neighboring cell with the lowest distance value
*/
//---------------------------------------------------------------
void setup() {
  size(520, 520);//, OPENGL); //rozmiar okna
  //noStroke();
  background(255);   //białe tło
  initMaze(); //inicjalizacja labiryntu
  readMaze("maze1.txt");
  printMaze(maze);
  //generateMaze();
}

float mx=25,my=25, //początkowa pozycja myszy
      x1=25, y1=25,
      dx=0.0,dy=0.0,
      delta=5;
int current_cell=0, next_cell=0, destination=119, 
    current_dir=E; //początkowy kierunek
int min_path=0, max_path=0;
boolean mouse_move=true; //flaga mozliwosci ruchu
//---------------------------------------------------------------
// draw
//---------------------------------------------------------------
void draw() {
    fill(255);
    rect(0,0,520, 520);
    drawMaze(maze,#000000); //ściany rzeczywiste
    
    // sensor read and floodfill
    sensorRead((int)((mx-20)/30),(int)((my-20)/30), current_dir); //sprawdzenie ścian w danym kwadracie; -20 to pasek graficzny; /30 aby wyliczył segment; kierunek dla odpowiedniej tabeli
    drawMaze(maze_pred,#DB1B1B); //rysowanie odkrytego labiryntu
    int t1=millis();
    for(int i=0;i<2;i++)
      floodfill(current_cell, destination, maze_pred);
    drawValues(mapa);//rysuje wartosci trasy
    fill(0);
    text("t="+(millis()-t1),20,15);
    
    if(current_cell==0) { min_path = mapa[0]; } //poczatek
    if(current_cell==119 && max_path<mapa[119]) { max_path = mapa[119]; min_path=0; }//znaleziony srodek
    
    if(min_path==max_path) mouse_move=false; 
    text(min_path,100,15);
    text(max_path,160,15);
    if(!mouse_move) drawPath(0,119,maze_pred);//rysuje obrany korytarz
    
    if(mouse_move)
    {
    // wyznaczenie nastepnego ruchu
    if(next_cell==current_cell && current_cell!=destination) {
      next_cell = step(current_cell, maze_pred);
      x1=mx;
      y1=my;
      // nowy kierunek, predkosc
      current_dir = getDIR(current_cell, next_cell);
      dx = (DN[current_dir]/16)*delta;
      dy = (DN[current_dir]%16)*delta;  
    }
    
    // nie osiagnieto celu - ruch myszy
    if(current_cell!=destination) {
        mx+=dx;
        my+=dy;
        // czy koniec ruchu w danym kierunku dystans = szerokosc komorki
        if(sqrt((mx-x1)*(mx-x1)+(my-y1)*(my-y1))>=30) current_cell=next_cell;
    } else { // cel osiagniety
        if(destination==119){//(to==119)||(to==120)||(to==135)||(to==136)) {
          current_cell=next_cell=destination;
          destination=0; //powrót
          //for(int i=0;i<256;i++) if(mapa[i]>mapa[0]) maze_pred[i]=N|S|W|E;   
        } 
        else {
          current_cell=next_cell=0; //po powrocie musi sobie przypomniec gdzie byl cel
          destination=119; 
          //for(int i=0;i<256;i++) if(mapa[i]>mapa[120]) maze_pred[i]=N|S|W|E;       
        }
    }
    }
    
    drawMouse((int)mx,(int)my, current_dir);
}

void mousePressed() {
    int xx=((mouseX-20)/30);
    int yy=((mouseY-20)/30);
    mx=xx*30+25;
    my=yy*30+25;
    current_dir=E;
    current_cell=next_cell=((mouseX-20)/30)*16 + ((mouseY-20)/30); 
}

//---------------------------------------------------------------
/*
.maz file
0x0f .. .. .. 0xff
.. .. .. .. ..
0x00 .. .. .. 0xf0
*/
//---------------------------------------------------------------
void readMaze(String file){
  BufferedReader reader;//bufor odczytu 
  String line; 
  reader = createReader(file);    
  int x=0,y=0;
  while(true) {
    
    try { 
      line = reader.readLine();  //odczyt linii
    } catch (IOException e) { //kontrola odczytu
      e.printStackTrace();
      line = null;
    }
    
    if (line == null) {
      // Stop reading because of an error or file is empty
      break;  
    } else {   
      String[] pieces = split(line, ' ');
      for(y=0;y<pieces.length;y++) {
        maze[x*Y+y] = unhex(pieces[y]);
      }
      x++;
    } 
  }
}

//---------------------------------------------------------------
// simple functions
//---------------------------------------------------------------
boolean isValid(int i, int dir) { // check if move is valid
   int nx,ny;
   nx = (i+DN[dir])/X; // nx = cx + DX[dir]
   ny = (i+DN[dir])%Y; // ny = cy + DX[dir]
   // check if we are on valid grid
   return ((nx >= 0) && (nx < X) && (ny >= 0) && (ny < Y));
}

int getDIR(int from, int to) { 
  int dn = to-from;  
  if(dn==1) return S;
  if(dn==-1) return N;
  if(dn==16) return E;
  if(dn==-16) return W;  
  return -1;
}

//ustawienie wstępne ścian labiryntu 
void initMaze() {
    for (int i=0; i<256; i++) maze_pred[i] = 0;  //wszystkie pola na zero, czyli gotowe do "tworzenia"
    for (int i = 0; i < X; i++) { maze_pred[i*Y+0] |= N;   maze_pred[i*Y+Y-1] |= S; } //ściany okalajace N i S
    for (int j = 0; j < Y; j++) { maze_pred[(X-1)*Y+j] |= E;  maze_pred[0*Y+j] |= W; }//ściany okalajace E i W
}

void sensorRead(int cx, int cy, int dir) {
    int i = cx*Y+cy;
    int[] sens = {N, E, W};
    if(dir==N) { ;    } // przod = N, lewo = W, prawo = E
    if(dir==E) { sens[2]=S; } // przod = E, lewo = N, prawo = S
    if(dir==S) { sens[0]=S; } // przod = S, lewo = E, prawo = W
    if(dir==W) { sens[1]=S; } // przod = W, lewo = S, prawo = N
  
    // 
    for(int j=0;j<3;j++) {
       dir = sens[j];
       if(isWall(i,dir)) { maze_pred[i] |= dir; if(isValid(i,dir)) maze_pred[i+DN[dir]] |= OPPOSITE[dir]; }
    }
}
//---------------------------------------------------------------
// maze generator
//---------------------------------------------------------------
void shuffle_array(int[] a) {
  int n = a.length;
  for(int i=0; i<(n - 1); i++) {
    int r = i + int(random(n - i));
    int temp = a[i];
    a[i] = a[r];
    a[r] = temp;
  }
}

void generateMazeReq(int cx, int cy) {
    int nx, ny, dir;
    int[] directions = {N, E, S, W};
    shuffle_array(directions);
    for (int i=0;i<4;i++) {
        dir = directions[i];
        nx = cx + DN[dir]/16; // nx = cx + DX[dir]
        ny = cy + DN[dir]%16; // ny = cy + DX[dir]
        // check if we are on valid grid && grid is not visited
        if ((nx >= 0) && (nx < X) && (ny >= 0) && (ny < Y) && (maze[nx*X+ny] == 15)) {
             maze[cx*X+cy] &= ~dir;
             maze[nx*X+ny] &= ~OPPOSITE[dir];
             generateMazeReq(nx, ny);
        }
    }
}
void generateMaze(){
    for(int i=0;i<256;i++) maze[i] = N|E|S|W;
    maze[119] = N|W;
    maze[120] = S|W;
    maze[135] = N|E;
    maze[136] = E|S;
//    int i,j;
//    for(i=0;i<100;i++) { j=(int)random(256); if((j/16)>0 && (j/16)<7 && (j%16)>0 && (j%16)<7) maze[j]=E|S|N; }
    generateMazeReq(8,8);
}
//---------------------------------------------------------------
// draw functions
//---------------------------------------------------------------
void drawMaze(int[] maze, color c) { //rysowanie linii labiryntu
    stroke(c);
    strokeWeight(3);
    for (int i = 0; i < Y; i++) {
         // N,W
         for (int j = 0; j < X; j++) {
              if((maze[j*X+i] & N) != 0) line(j*30+20, i*30+20, j*30+30+20, i*30+20); //20 to przesunięcie, bok segmentu ma 30
              if((maze[j*X+i] & W) != 0) line(j*30+20, i*30+20, j*30+20, i*30+30+20);
         }
         // E
         if((maze[(Y-1)*X+i] & E) != 0) line(X*30+20, i*30+20, X*30+20, i*30+30+20);
    }
    // S
    for (int j = 0; j < X; j++) {
          if((maze[j*X+Y-1] & S) != 0) line(j*30+20, Y*30+20, j*30+30+20, Y*30+20);
    }
}

void printMaze(int[] maze) { //do okienka na dole
   int i,j;
   // N
   print(" "); 
   for(i=0;i<X;i++) 
       if(isWall(i*Y+0,N)) print("_ "); //sprawdza czy jest bit N w danym segmencie
   println();
   
   for (j = 0; j < Y; j++) {
         // E, S
         for (i = 0; i < X; i++) {
              if(isWall(i*Y+j,W)) print("|"); else print(" ");
              if(isWall(i*Y+j,S)) print("_"); else print(" ");
         }
         // W
         if(isWall((X-1)*Y+j,E)) print("|");
         println();
    }
 // "_"
   //for(i=0;i<X;i++) print("__");
}

void drawValue(int position, int[] values, color c) {
    int i,j; 
    j=position/16;
    i=position%16;
    fill(c);
    rect(j*30+22, i*30+22, 27, 27); 
    fill(128); 
    text(values[j*X+i], j*30+25, i*30+40);
}

void drawValues(int[] values) {
    noStroke();
    for(int i=0;i<256;i++) 
      drawValue(i,values,240);
}

void drawMouse(int mx, int my, int dir) {
  stroke(#aa0000);
  strokeWeight(3);
  translate(mx, my);
  if((dir&N)!=0) { line(10,-5,10,10); line(-5,5,10,5); line(10,5,25,5); }
  if((dir&E)!=0) { line(10,10,25,10); line(15,-5,15,10); line(15,10,15,25); }
  if((dir&S)!=0) { line(10,10,10,25); line(-5,15,10,15); line(10,15,25,15); }
  if((dir&W)!=0) { line(-5,10,10,10); line(5,-5,5,10); line(5,10,5,25); }
  fill(200);
  stroke(0);
  strokeWeight(1);
  rect(0,0,20,20);
}

void drawPath(int current_cell, int destination, int[] maze_pred) {
  int i,j;
  do {
     drawValue(current_cell, mapa, #ffff00);
     current_cell=step(current_cell, maze_pred);
  } while(current_cell!=destination);
  drawValue(current_cell, mapa, #ffff00);
}


int[] stack  = new int[512];
int top=0;
void Push(int value) { stack[++top]=value; }
int Top() { return stack[top]; }
int Pop() { return stack[top--]; }

//Array to hold the Floodfill algorithm's values
int[] wallflood ={
  14, 13, 12, 11, 10, 9, 8, 7, 7, 8, 9, 10, 11, 12, 13, 14,
  13, 12, 11, 10,  9, 8, 7, 6, 6, 7, 8,  9, 10, 11, 12, 13,
  12, 11, 10,  9,  8, 7, 6, 5, 5, 6, 7,  8,  9, 10, 11, 12,
  11, 10,  9,  8,  7, 6, 5, 4, 4, 5, 6,  7,  8,  9, 10, 11,
  10,  9,  8,  7,  6, 5, 4, 3, 3, 4, 5,  6,  7,  8,  9, 10,
   9,  8,  7,  6,  5, 4, 3, 2, 2, 3, 4,  5,  6,  7,  8,  9,
   8,  7,  6,  5,  4, 3, 2, 1, 1, 2, 3,  4,  5,  6,  7,  8,
   9,  6,  5,  4,  3, 2, 1, 0, 0, 1, 2,  3,  4,  5,  6,  7,
   7,  6,  5,  4,  3, 2, 1, 0, 0, 1, 2,  3,  4,  5,  6,  7,
   8,  7,  6,  5,  4, 3, 2, 1, 1, 2, 3,  4,  5,  6,  7,  8,
   9,  8,  7,  6,  5, 4, 3, 2, 2, 3, 4,  5,  6,  7,  8,  9,
  10,  9,  8,  7,  6, 5, 4, 3, 3, 4, 5,  6,  7,  8,  9, 10,
  11, 10,  9,  8,  7, 6, 5, 4, 4, 5, 6,  7,  8,  9, 10, 11,
  12, 11, 10,  9,  8, 7, 6, 5, 5, 6, 7,  8,  9, 10, 11, 12,
  13, 12, 11, 10,  9, 8, 7, 6, 6, 7, 8,  9, 10, 11, 12, 13,
  14, 13, 12, 11, 10, 9, 8, 7, 7, 8, 9, 10, 11, 12, 13, 14
};

//---------------------------------------------------------------
// flood-fill
//---------------------------------------------------------------
/*
1. Start at Starting cell 
2. Check all accessible cells’ values 
3. Move to accessible cell with lowest value 
4. Repeat 2 – 4 until the target cell is reached 
*/

int step(int current_cell, int[] maze) {
  int i,j,ndir=current_dir,npos,min,dir;
  int[] directions = {N, E, S, W};
  
  i=npos=current_cell;
  // znajdz nastepny ruch o najmniejszej wadze
  min=255;        
  for (int k=0; k<4; k++) {
     dir = directions[k];
     if(((maze[i] & dir) == 0)) { // jesli przejscie w kierunku dir
         j = i + DN[dir];
         if(min>mapa[j]) { min=mapa[j]; ndir=dir; npos=j; }        
     }
  } 
  // probuj jechac w tym samym kierunku
  for (int k=0; k<4; k++) {
     dir = directions[k];
     if(((maze[i] & dir) == 0)) { // jesli przejscie w kierunku dir
         j = i + DN[dir];
         if(mapa[j]==min && getDIR(current_cell,j)==current_dir) {  npos=j; }        
     }
  } 
  return npos;
}



int floodfill(int current_cell, int destination, int[] maze)
{
  int[] directions = {N, E, S, W};
  int i,j,dir;
  boolean finish=false;
  int dirplus = 0;
  /*
  Let variable Level = 0
  Initialize the array DistanceValue so that all values = 255
  Place the destination cell in an array called CurrentLevel
  Initialize a second array called NextLevel
  */
  for(i=0; i<256; i++) mapa[i] = 255;
  
  int level = 0;
  int[] CurrLevel=new int[16*4];
  int currlevel=0;
  int[] NextLevel=new int[16*4];
  int nextlevel=0;

//Dodatki wagowe

  CurrLevel[currlevel++] = destination; // w pozycji 0 zapisany cel
  
  do {
  // While CurrentLevel is !empty:
  while(currlevel!=0){
    
    
    i = CurrLevel[--currlevel]; //przypisanie położenia celu
    if (mapa[i]==255) { //jeśli odległość do celu jest nieokreślona    
           for (int k=0; k<4; k++) { //rozgląda się wokół segmentu   
           dir = directions[k];
           if(((maze[i] & dir) == 0)) { // otwarta ściana
              j = i + DN[dir];          //wytypowany następny ruch(y)
              if(mapa[j]==255) NextLevel[nextlevel++] = k;       //jeśli następny typ jest nieokreślony to wchodzi do next level
              
           }
        }
     }
  
  }
  
 
  
  if(nextlevel==0) return 0;
  level++;
  //while(nextlevel>0) CurrLevel[currlevel++] = NextLevel[--nextlevel];

      TempLevel = CurrLevel;
  CurrLevel = NextLevel;
  currlevel = nextlevel;  
      NextLevel = TempLevel;
  nextlevel=0;
 
  } while(!finish);
  
  return 1;
}

