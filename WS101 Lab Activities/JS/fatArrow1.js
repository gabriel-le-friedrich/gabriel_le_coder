

aSquare = (s) => {return s*s};
pSquare = (s) => {return 4*s};
aRect = (l,w) => {return l*w};
pRect = (l,w) => {return 2*(l*w)};

const whatShape = (shape) =>
{

    if(shape==='square')
    {
    console.log
    (`
    Area of a Square is: ${aSquare(4)}
    Perimeter of a Square is: ${pSquare(4)}
    `);
    }

    else if(shape==='rect')
    {
    console.log
    (`
    Area of a Rect is: ${aRect(4,2)}
    Perimeter of a Rect is: ${pRect(4,2)}
  `);
    }
};


//computeArea1 = (l,w) => {return l*w}; //Fat Arrow equivalent

function computeA(l,w)
{
  return l*w;
}


//computeArea(5,2);
//console.log("The Area is:"+computeArea1 (9,4));
//console.log("Area is:" + computeA (3,4));

whatShape('square');
whatShape('rect');

