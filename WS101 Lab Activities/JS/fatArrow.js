

const computeArea = (ln,wd) => {
   let area = ln * wd; 
    console.log
    (`
    Length is: ${ln}
    Width is:  ${wd}
    Area is:   ${area}
  `);
};


computeArea1 = (l,w) => {return l*w}; //Fat Arrow equivalent

function computeA(l,w) {
  return l*w;
}




computeArea(5,2);
console.log("The Area is:"+computeArea1 (9,4));
console.log("Area is" + computeA (3,4));