import { Injectable } from '@angular/core';
import { CanActivate, ActivatedRouteSnapshot, RouterStateSnapshot, Router } from '@angular/router';

@Injectable({
  providedIn: 'root'
})
export class AuthGuard implements CanActivate {

  constructor(private router: Router) {}

  canActivate(route: ActivatedRouteSnapshot): boolean {
    const userType = localStorage.getItem('userType');
    const allowedRoles = route.data['roles'] as string[];

    if (allowedRoles.includes(userType!)) {
      return true;
    }

    // Redirecionar para login se não tiver permissão
    this.router.navigate(['/login']);
    return false;
  }
}
