import { Pipe, PipeTransform } from '@angular/core';

@Pipe({
  name: 'filterUtentes',
  standalone: true  // <-- adiciona isso

})
export class FilterUtentesPipe implements PipeTransform {
  transform(utentes: any[], nome: string, numero: string): any[] {
    if (!utentes) return [];

    return utentes.filter(u => {
      const nomeMatch = nome ? u.nome.toLowerCase().includes(nome.toLowerCase()) : true;
      const numeroMatch = numero ? u.numeroUtente.toString().includes(numero) : true;
      return nomeMatch && numeroMatch;
    });
  }
}
