module harenae.update.Sand;

import harenae.all;

final class Sand {
public:
    this(uint2 size, bool delegate() coinToss) {
        this.size = size;
        this.w = size.x;
        this.h = size.y;
        this.coinToss = coinToss;
    }
    void update(uint[] cells) {

        flipFlop = !flipFlop;

        int X_START = 0, X_END = w-1, X_DELTA = 1;

        if(flipFlop) {
            X_START = w-1, X_END = 0, X_DELTA = -1;
        } 
        
        for (int y = h - 1; y >= 0; y--) {
            if(flipFlop) {
                for (int x = 0; x < w; x++) {
                    processCell(cells, x, y);
                }
            } else {
                for (int x = w-1; x >= 0; x--) {    
                    processCell(cells, x, y);
                }
            }
        }
    }
private:
    uint2 size;
    int w;
    int h;
    bool delegate() coinToss;
    bool flipFlop;

    void processCell(uint[] cells, int x, int y) {
        int i = x+y*w;

        if (cells[i] == CellType.SAND) {  

            bool okDown = y<h-1 && cells[i+w]==0;   

            if(okDown) {   
                cells[i] = 0; 
                cells[i+w] = CellType.SAND; 
            } else {
                int dir = x==0 ? 1 : 
                            x==w-1 ? -1 : 
                            coinToss() ? -1 : 1; 
                bool okDownDiag = y<h-1 && cells[i+dir + w]==0;    
                if (okDownDiag) { 
                    cells[i] = 0; 
                    cells[i+dir+w] = CellType.SAND; 
                } 
            }
        }
    }
}